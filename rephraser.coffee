sys = require("util")
http = require("http")
url = require("url")
_ = require("underscore")

Express = require("express")

corsetCase = (string) ->
  string.toLowerCase().replace /(^|-)(\w)/g, (s) ->
    s.toUpperCase()

status = (phrase) ->
  phrase.status = parseInt(phrase.request.url.slice(1, 4))

jsonize = (phrase) ->
  phrase.body = JSON.stringify(
    method: phrase.request.method
    url: phrase.request.url
    headers: _(phrase.request.headers).reduce((hash, value, key) ->
      hash[corsetCase(key)] = value
      hash
    , {})
    body: phrase.request.body
  )

location = (phrase) ->
  phrase.headers["Location"] = "#{phrase.baseURL}/200"

defineRules = (rephraser) ->
  rephraser.server.get "/200", rephraser.send(status, jsonize)
  rephraser.server.post "/200", rephraser.send(status, jsonize)
  rephraser.server.post "/201", rephraser.send(status, jsonize, location)
  rephraser.server.options "/201", rephraser.send()
  rephraser.server.post "/204", rephraser.send(status)
  rephraser.server.get "/404", rephraser.send(status, jsonize)
  rephraser.server.get "/301", rephraser.send(status, location)
  rephraser.server.get "/302", rephraser.send(status, location)
  rephraser.server.get "/timeout", -> # do nothing

class Rephraser

  @run: (options) ->
    (new Rephraser(options)).run()

  constructor: (@configuration) ->
    # configuration.url is allowed to end with a /.
    url = @configuration.url
    if url[url.length-1] == "/"
      @configuration.url = url.slice(0, -1)

    @server = Express.createServer(Express.bodyParser())

    defineRules @

  run: ->
    process.on "exit", -> console.log "Rephraser exiting."
    @server.listen @configuration.port, @configuration.address
    console.log "Running Rephraser at #{@configuration.url}"

  send: (args...) ->
    (request, response) =>
      phrase =
        request: request
        response: response
        status: 200
        headers: {}
        body: ""
        baseURL: @configuration.url

      for fn in args
        fn(phrase)

      response.setHeader "Content-Length", phrase.body.length
      response.setHeader "Content-Type", "application/json"
      response.setHeader "Access-Control-Max-Age", 1
      response.setHeader "Access-Control-Allow-Origin", "null"
      response.setHeader "Access-Control-Allow-Method", "GET,POST"
      response.setHeader "Access-Control-Allow-Headers", "accept,content-type,content-length"
      response.send phrase.body, phrase.headers, phrase.status

module.exports = Rephraser
