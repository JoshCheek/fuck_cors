require_relative 'not_rails'

remote = 'http://localhost:3011' # local (works)
remote = 'http://localhost:3010' # remote (fails b/c cors)
users  = []

serve 3011, {
  ['GET', '/'] => lambda do |request_headers, body|
    [200, {'Content-Type' => 'text/html'}, <<~HTML]
    <h1>A remotely created user:</h1>
    <p>from #{request_headers['Host'].inspect}, to #{remote.inspect}</p>
    <div id=div></div>

    <script>
    fetch("#{remote}/users", {
      method: 'POST',
      body:   '{"name":"Josh"}',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
    })
    .then(
      async (res) => div.innerText = JSON.stringify(await res.json()),
      async (err) => div.innerText = err,
    )
    </script>
    HTML
  end,

  ['POST', '/users'] => lambda do |request_headers, body|
    user = JSON.parse body
    users.push user
    user['id'] = users.size
    [200, {'Content-Type' => 'application/json'}, JSON.dump(user)]
  end,
}

