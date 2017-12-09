# encoding: UTF-8
require 'kintone_deploy/version'
require 'kintone_deploy/multi-part-form-data-stream'
require 'kintone_deploy/kintone-api'
require 'json'
require 'optparse'
require 'diff/lcs'

module KintoneDeploy
    def deploy(option, deploy_data)
        api = KintoneHTTP_API.new(option[:d], deploy_data['id'], option[:u], option[:p], option[:basic_id], option[:basic_pw])
        upload_result = {
            "js" => [],
            "css" => [],
            "mobile_js" => []
        }

        puts "[INFO] Uploading files..."
        upload_result.keys.each do |type|
            deploy_data[type].each do |entry|
                if entry.include?('https://')
                    upload_result[type].push({
                        :type => 'URL',
                        :url  => entry
                    })
                else
                    begin
                        File.open(entry) do |fd|
                            content_type = (type == 'css' ? "text/css" : "text/javascript")
                            result = api.uploadFile(fd.read, File.basename(entry), content_type)
                            upload_result[type].push({
                                :type => 'FILE',
                                :file => {
                                    :fileKey => result['fileKey']
                                }
                            })
                        end
                    rescue Errno::ENOENT => err
                        STDERR.puts "No such file: #{entry}"
                        exit
                    rescue => err
                        STDERR.puts err.to_s
                        exit
                    end
                end
            end
        end

        puts "[INFO] Deploying files into preview..."
        customize_result = api.http_request(Net::HTTP::Put, '/preview/app/customize.json', {
            :app => deploy_data['id'],
            :scope => 'ALL',
            :desktop => {
                :js => upload_result['js'],
                :css => upload_result['css']
            },
            :mobile => {
                :js => upload_result['mobile_js']
            }
        })

        if(option[:t] == nil)
            puts "[INFO] Deploying preview to production..."
            deploy_result = api.http_request(Net::HTTP::Post, '/preview/app/deploy.json', {
                :apps => [
                    {
                        :app => deploy_data['id'],
                        :revision => customize_result['revision']
                    }
                ]
            })
        end

        puts "[INFO] Deployment is completed."
    end

    def verify(option, deploy_data)
        identical = true
        api = KintoneHTTP_API.new(option[:d], deploy_data['id'], option[:u], option[:p], option[:basic_id], option[:basic_pw])
        customize = api.http_request(Net::HTTP::Get, '/preview/app/customize.json', {:app => deploy_data['id']})

        puts "[INFO] Vefiry desktop JS list..."
        kintone_desktop_js = customize['desktop']['js'].map{|e| e['type'] == 'FILE' ? e['file']['name'] : e['url']}
        local_desktop_js   = deploy_data['js'].map{|e| e.include?('https:') ? e : File.basename(e)}
        if local_desktop_js == kintone_desktop_js
            puts "[INFO] Desktop JS list is identical."
        else
            puts "[WARN] Desktop JS list is different."
            identical = false
            diffs = Diff::LCS.diff(local_desktop_js, kintone_desktop_js)
            show_diffs(diffs)
        end

        puts "[INFO] Vefiry mobile JS list..."
        kintone_mobile_js = customize['mobile']['js'].map{|e| e['type'] == 'FILE' ? e['file']['name'] : e['url']}
        local_mobile_js   = deploy_data['mobile_js'].map{|e| e.include?('https:') ? e : File.basename(e)}
        if local_mobile_js == kintone_mobile_js
            puts "[INFO] Mobile JS list is identical."
        else
            puts "[WARN] Mobile JS list is different."
            identical = false
            diffs = Diff::LCS.diff(local_mobile_js, kintone_mobile_js)
            show_diffs(diffs)
        end

        puts "[INFO] Vefiry desktop JS file..."
        desktop_js = customize['desktop']['js'].map{|e|
            {:fileKey => e['file']['fileKey'], :name => e['file']['name']} if e['type'] == 'FILE'
        }
        desktop_js.each do |js|
            next if js == nil
            local_file = open(local_file_path(js[:name], deploy_data, 'js')).read
            kintone_file = api.http_request(Net::HTTP::Get, 'file.json', {
                :fileKey => js[:fileKey]
            }).force_encoding(local_file.encoding.name)

            diffs = Diff::LCS.diff(local_file.split("\n"), kintone_file.split("\n"))
            if diffs.length == 0
                puts "[INFO] Desktop JS file (#{js[:name]}) is identical."
            else
                puts "[WARN] Desktop JS file (#{js[:name]}) is different."
                identical = false
                show_diffs(diffs)
            end
        end

        puts "[INFO] Vefiry mobile JS file..."
        mobile_js = customize['mobile']['js'].map{|e|
            {:fileKey => e['file']['fileKey'], :name => e['file']['name']} if e['type'] == 'FILE'
        }
        mobile_js.each do |js|
            next if js == nil
            local_file = open(local_file_path(js[:name], deploy_data, 'mobile_js')).read
            kintone_file = api.http_request(Net::HTTP::Get, 'file.json', {
                :fileKey => js[:fileKey]
            }).force_encoding(local_file.encoding.name)

            diffs = Diff::LCS.diff(local_file.split("\n"), kintone_file.split("\n"))
            if diffs.length == 0
                puts "[INFO] Mobile JS file (#{js[:name]}) is identical."
            else
                puts "[WARN] Mobile JS file (#{js[:name]}) is different."
                identical = false
                show_diffs(diffs)
            end
        end

        if identical
            puts ""
            puts "[INFO] Everything is identical"
        else
            puts ""
            puts "-------------------------------------------------------------------------"
            puts "[WARN] There are some differences between kintone settings and local file."
            puts "-------------------------------------------------------------------------"
        end
    end

    def show_diffs(diffs)
        diffs.each do |diff|
            puts '-----'
            diff.each do |line|
                puts line.inspect
            end
        end
    end

    def local_file_path(file_name, deploy_data, desktop_or_mobile)
        result = deploy_data[desktop_or_mobile].select{|e| e.include?(file_name) && !e.include?('https:')}
        return result[0] if result.length != 0
    end

    module_function :deploy, :verify, :show_diffs, :local_file_path


    option = {}
    optparse = OptionParser.new do |opt|
        opt.on('-i [app.json]', 'app.json')         {|v| option[:i] = v}
        opt.on('-d domain',     'Domain name')      {|v| option[:d] = v}
        opt.on('-u user id',    'Account name')     {|v| option[:u] = v}
        opt.on('-p password',   'Account password') {|v| option[:p] = v}
        opt.on('-t', 'Deploy preview environment')  {|v| option[:t] = v}
        opt.on('-v', 'Verify deployment')  {|v| option[:v] = v}
        opt.on('-b, --basic-id user id',  'Basic Auth ID')        {|v| option[:basic_id] = v}
        opt.on('-q, --basic-pw password', 'Basic Auth password')  {|v| option[:basic_pw] = v}
    end

    begin
        optparse.parse!(ARGV)
        mandatory = [:d, :u, :p]
        missing = mandatory.select{ |param| option[param].nil? }
        unless missing.empty?
            raise OptionParser::MissingArgument.new(missing.join(', '))
        end
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument
        puts $!.to_s
        puts optparse
        exit
    end

    begin
        deploy_data = JSON.parse(open(option[:i] || 'app.json').read)
    rescue Errno::ENOENT => err
        STDERR.puts "There is no app.json"
        exit
    rescue JSON::ParserError => err
        STDERR.puts "JSON parse error in app.json"
        STDERR.puts err.to_s
        exit
    end

    if(option[:v] == nil)
        KintoneDeploy.deploy(option, deploy_data)
    else
        KintoneDeploy.verify(option, deploy_data)
    end
end
