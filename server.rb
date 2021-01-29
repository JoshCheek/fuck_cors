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

  ['POST', '/users'] => lambda do |request_headers, body|
    user = JSON.parse body
    users.push user
    user['id'] = users.size
    [200, {'Content-Type' => 'application/json'}, JSON.dump(user)]
  end,
}
