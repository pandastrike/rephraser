http = require("http")
URL = require("url")

module.exports = class Rephraser

  @run: (configuration) ->
    (new Rephraser(configuration)).run()

  run: ->
    process.on "exit", -> console.log "Rephraser exiting."
    @server.listen @configuration.port, @configuration.host
    console.log "Running Rephraser at #{@configuration.url}"

  constructor: (@configuration) ->
    # configuration.url is allowed to end with a /.
    url = @configuration.url
    if url[url.length-1] == "/"
      @configuration.url = url.slice(0, -1)

    @server = http.createServer (request, response) =>

      chunks = []
      request.on "data", (chunk) =>
        chunks.push chunk

      request.on "end", =>
        request.body = chunks.join()
        @handle(request, response)

  handle: (request, response) ->
    result = @dispatch(request, response)
    return if result == null
    {status, headers, content} = result
    if headers
      for key, value of headers
        response.setHeader key, value

    if content == null
      body = ""
    else
      body = JSON.stringify(content, null, 2)
      response.setHeader "Content-Type", "application/json"
      response.setHeader "Content-Length", Buffer.byteLength(body)

    response.writeHead status
    response.end body

  # returns an object containing status and content properties
  dispatch: (request, response) ->
    url = URL.parse(request.url)
    path = url.path

    content =
      method: request.method
      url: request.url
      headers: {}
      body: request.body
    for key, value of request.headers
      content.headers[@corsetCase(key)] = value

    switch path
      when "/200"
        status: 200
        content: content
      when "/201"
        status: 201
        headers:
          "Location": "#{@configuration.url}/200"
        content: content
      when "/204"
        status: 204
        content: null
      when "/301"
        status: 301
        headers:
          "Location": "#{@configuration.url}/200"
        content: null
      when "/302"
        status: 302
        headers:
          "Location": "#{@configuration.url}/200"
        content: null
      #when "/500"
      #when "/501"
      #when "/502"
      when "/timeout"
        console.log "Letting a request hang forever. Ha ha!"
        null
      else
        status: 404
        content: content

  corsetCase: (string) ->
    string.toLowerCase().replace /(^|-)(\w)/g, (s) ->
      s.toUpperCase()



