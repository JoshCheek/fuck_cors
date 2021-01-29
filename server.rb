require_relative 'not_rails'

users = []
serve 3010, {
  ['GET', '/'] => lambda do |request_headers, body|
    [200, {'Content-Type' => 'text/html'}, ERB.new(<<~HTML).result(binding)]
    <h1>Users</h1>
    <table>
      <tr><th>id</th><th>name</th></tr>
      <% users.each do |user| %>
        <tr>
          <td><%= user['id']   %></td>
          <td><%= user['name'] %></td>
        </tr>
      <% end %>
    </table>
    HTML
  end,

  ['OPTIONS', '/users'] => lambda do |request_headers, body|
    # Just based on the example of "preflighted requests" here:
    # https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
    #
    # List of headers is here:
    # https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#the_http_response_headers
    headers = {}
    headers['Access-Control-Allow-Origin'] = 'http://localhost:3011'
    headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type'
    headers['Access-Control-Max-Age'] = '5' # only 5s so that caching doesn't mess up future tests
    [204, headers, '']
  end,

  ['POST', '/users'] => lambda do |request_headers, body|
    headers = {}
    headers['Content-Type'] = 'application/json'
    headers['Access-Control-Allow-Origin'] = 'http://localhost:3011'
    user = JSON.parse body
    users.push user
    user['id'] = users.size
    [200, headers, JSON.dump(user)]
  end,
}
