var sys = require("util")
  , http = require("http")
  , url = require("url")
  , _ = require("underscore")
  , Express = require("express")
  , corsetCase = function(string) {
    return string.toLowerCase().replace(/(^|-)(\w)/g, function(s) { 
        return s.toUpperCase(); });
  }
  , makeServer = function(rephraser) {
      rephraser.server = Express.createServer(
          Express.logger({stream: rephraser.log.stream}),
          Express.bodyParser()
      );
    }
  , status = function(phrase) {
    phrase.status = parseInt(phrase.request.url.slice(1,4));
    return phrase;
  }
  , jsonize = function(phrase) {
    phrase.body = JSON.stringify({
      method : phrase.request.method,
      url : phrase.request.url,
      headers : _(phrase.request.headers).reduce(function(hash,value,key) {
        hash[corsetCase(key)] = value;
        return hash;
      },{}),
      body : phrase.request.body
    });
    _.extend(phrase.headers, {
      "Content-Length" : phrase.body.length,
      "Content-Type" : "application/json"
    });
    return phrase;
  }
  , location = function(phrase) {
    phrase.headers["Location"] = phrase.baseURL + "/200";
    return phrase;
  }
  , defineRules = function(rephraser) {
    rephraser.server.get("/200", rephraser.send(status,jsonize));
    rephraser.server.post("/200", rephraser.send(status,jsonize));
    rephraser.server.post("/201", rephraser.send(status,jsonize,location));
    rephraser.server.post("/204", rephraser.send(status));
    rephraser.server.get("/301", rephraser.send(status,location));
    rephraser.server.get("/302", rephraser.send(status,location));
    rephraser.server.get('/timeout', function () { /* do nothing */ } )
  }
;
  
//Express.bodyParser.parse['text/plain'] = function(s) { return s; }

var Rephraser = function(options) {
  this.configuration = options;
  makeServer(this);
  defineRules(this);
};

Rephraser.prototype = {
  run: function() {
    var rephraser = this
      , where = [this.configuration.address,
          this.configuration.port].join(":")
      , log = function(message) {
        // we normally only use the logger
        // also log to console for start/stop
        process.stdout.write(message); 
        rephraser.log.info(message);
      }
    ;
    process.on("exit", function() { log("Rephraser exiting."); });
    this.server.listen(this.configuration.port,this.configuration.address);
    log("Starting up rephraser on [" + where + "]");    
  },
  send: function() {
    var _arguments = _(arguments)
      , rephraser = this
    ;
    return function(_request,_response) {
      var phrase = {
        request: _request,
        response: _response,
        status: 200,
        headers: {},
        body: "",
        baseURL: "http://" + rephraser.configuration.address
            + ":" + rephraser.configuration.port
      };
      phrase = _arguments.reduce(function(result,fn) {
        return fn(result);
      }, phrase);
      _response.send(phrase.body, phrase.headers, phrase.status);
    };
  }
};

Object.defineProperties(Rephraser.prototype, {
  log: {
    get: function() { return this.configuration.logger; }
  }
});

Rephraser.run = function(options) { return (new Rephraser(options)).run(); };

module.exports = Rephraser;
