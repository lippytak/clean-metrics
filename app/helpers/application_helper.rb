module ApplicationHelper
  def create_plot(origin, data, kwargs)
    # See REST API docs: https://plot.ly/rest/
    uri = URI.parse("https://plot.ly/clientresp")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({"un" => ENV['PLOTLY_USERNAME'],
                          "key" => ENV['PLOTLY_KEY'],
                          "origin" => origin,
                          "platform" => "ruby",
                          "args" => data.to_json,
                          "kwargs" => kwargs.to_json})
    response = http.request(request)
    response_json = JSON.parse(response.body)
    response_json['url']
  end
end
