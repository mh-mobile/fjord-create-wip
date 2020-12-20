# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "date"

LOGINNAME = ENV["loginname"]
PASSWORD = ENV["password"]
TITLE = "WIP"
DESCRIPTION = "## やったこと\r\n\r\n## つぎにやること"

def request_options(uri)
  { use_ssl: uri.scheme == "https" }
end

def fetch_jwt_token
  uri = URI.parse("https://bootcamp.fjord.jp/api/session")
  request = Net::HTTP::Post.new(uri)
  request.content_type = "application/json"
  request.body = JSON.dump({
                             "login_name" => LOGINNAME,
                             "password" => PASSWORD
                           })
  response = http_request(uri, request)
  response.body.gsub(/{\"token\":\"|"}/, "")
end

def http_request(uri, request)
  Net::HTTP.start(uri.hostname, uri.port, request_options(uri)) do |http|
    http.request(request)
  end
end

def fetch_csrf_token
  uri = URI.parse("https://bootcamp.fjord.jp/")
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = fetch_jwt_token
  response = http_request(uri, request)
  re = Regexp.new("csrf-token.+?==")
  s = response.body
  csrf_token = re.match(s).to_s.gsub('csrf-token" content="', "")
  { csrf_token: csrf_token, cookie: extract_cookie(response) }
end

def extract_cookie(response)
  cookie = {}
  response.get_fields("Set-Cookie").each do |str|
    k, v = str[0...str.index(";")].split("=")
    cookie[k] = v
  end
  cookie
end

def add_cookie(request, cookie)
  request.add_field("Cookie", cookie.map do |k, v|
    "#{k}=#{v}"
  end.join(";"))
  request
end

def create_report(params, token)
  uri = URI.parse("https://bootcamp.fjord.jp/reports/")
  request = Net::HTTP::Post.new(uri)
  request.content_type = "application/json"
  request.body = JSON.dump(params)
  request = add_cookie(request, token[:cookie])
  http_request(uri, request)
end

token = fetch_csrf_token
params = {
  "authenticity_token" => token[:csrf_token],
  "report" => {
    "title" => TITLE,
    "reported_on" => Date.today.to_s,
    "emotion" => "soso",
    "learning_times_attributes" => {
      "0" => {
        "started_at(1i)" => "2020",
        "started_at(2i)" => "12",
        "started_at(3i)" => "19",
        "started_at(4i)" => "22",
        "started_at(5i)" => "00",
        "finished_at(1i)" => "2020",
        "finished_at(2i)" => "12",
        "finished_at(3i)" => "19",
        "finished_at(4i)" => "22",
        "finished_at(5i)" => "00",
        "_destroy" => "false"
      }
    },
    "description" => DESCRIPTION
  },
  "commit" => "WIP"
}

if (PASSWORD == "password") && (LOGINNAME == "username")
  p "LOGINNAMEとPASSWORDを設定してください"
  exit
end

puts params
puts token


create_report(params, token)
