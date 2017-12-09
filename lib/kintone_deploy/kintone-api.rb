require 'uri'
require 'base64'
require 'net/https'

class KintoneHTTP_API
    def initialize(kintone_host, app_id, auth_id = nil, auth_pw = nil, basic_auth_id = nil, basic_auth_pw = nil)
        @app_id        = app_id
        @kintone_host  = kintone_host.include?('cybozu.com') ? kintone_host : "#{kintone_host}.cybozu.com"
        @auth_id       = auth_id
        @auth_pw       = auth_pw
        @basic_auth_id = basic_auth_id
        @basic_auth_pw = basic_auth_pw
    end

    def kintone_auth_token(id, pw)
        Base64.encode64("#{id}:#{pw}").chomp
    end

    def basic_auth_token
        Base64.encode64("#{@basic_auth_id}:#{@basic_auth_pw}").chomp
    end

    #  Create HTTPS object for KINTONE
    def https
        if @http == nil
            @http = Net::HTTP.new(@kintone_host, 443)
            @http.use_ssl = true
        end
        return @http
    end

    #  Create http request object for KINTONE
    #  rec: 'record.json' or 'records.json' defined in KITONE API document
    def http_request(method_class, rec, data)
        req_header = {"Content-Type" => "application/json"}

        if @auth_id
            req_header["X-Cybozu-Authorization"] = kintone_auth_token(@auth_id, @auth_pw)
        elsif @basic_auth_id
            req_header["Authorization"] = "Basic #{basic_auth_token}"
        else
            raise 'No auth infomation.'
        end

        req = method_class.new("/k/v1/#{rec}", req_header)
        req.body = data.to_json
        res = https.request(req)
        return res.body if rec.include?('file.json')
        result = JSON.parse(res.body)
        if result["message"] != nil
            raise "KINTONE ACCESS ERROR: #{result['message']} data:#{data.to_json}"
        end

        return result
    end

    def uploadFile(data, outfilename, content_type)
        req_header = {}

        if @auth_id
            req_header["X-Cybozu-Authorization"] = kintone_auth_token(@auth_id, @auth_pw)
        elsif @basic_auth_id
            req_header["Authorization"] = "Basic #{basic_auth_token}"
        else
            raise 'No auth infomation.'
        end

        boundary = "----------------------KINTONEDEPLOY"
        body_stream = MultiPartFormDataStream.new(outfilename, StringIO.new(data), boundary, content_type)

        req = Net::HTTP::Post.new("/k/v1/file.json", req_header)
        req["Content-Type"]   = body_stream.content_type
        req["Content-Length"] = body_stream.size

        req.body_stream = body_stream
        res = https.request(req)
        raise "Please check your domain name. HTTP Status Code:#{res.code}" if !res.kind_of?(Net::HTTPOK)

        result = JSON.parse(res.body)

        if result["message"] != nil
            raise "KINTONE ACCESS ERROR: #{result['message']}"
        end
        return result
    end
end
