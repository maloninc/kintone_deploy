require 'kintone_deploy/version'
require 'kintone_deploy/multi-part-form-data-stream'
require 'kintone_deploy/kintone-api'
require 'json'
require 'optparse'

module KintoneDeploy

    option = {}
    optparse = OptionParser.new do |opt|
        opt.on('-i [app.json]', 'app.json')         {|v| option[:i] = v}
        opt.on('-d domain',     'Domain name')      {|v| option[:d] = v}
        opt.on('-u user id',    'Account name')     {|v| option[:u] = v}
        opt.on('-p password',   'Account password') {|v| option[:p] = v}
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
                        result = api.uploadFile(fd.read, entry, "text/javascript")
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

    puts "[INFO] Deploying files..."
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

    deploy_result = api.http_request(Net::HTTP::Post, '/preview/app/deploy.json', {
        :apps => [
            {
                :app => deploy_data['id'],
                :revision => customize_result['revision']
            }
        ]
    })

    puts "[INFO] Deployment is completed."
end
