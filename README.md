Reaxt
=====

Use your [React](http://facebook.github.io/react/) components into your elixir application, using [webpack](http://webpack.github.io/) compilation, so :

- An isomorphic ready library (SEO/JS are now nice together), but with Elixir on the server side
- Just a Library, with a minimum constraint about your application organization and layout :
  - use any javascript compiled language
  - use any javascript routing logic or library
  - you can use JS React rendered component only for parts of your webpage
- Nice fluent dev workflow, with :
  - combined stacktrace : elixir | javascript
  - hot loading on both server and browser
  - NPM/Webpack as the only config for respectively dependencies/compilation
  - A cool UI to have an overview of your compiled javascript application
  - You do not have to think about the server side Javascript configuration, 
    just write a webpack conf for the browser, and it is ready to use.

## Usage ##

See https://github.com/awetzel/reaxt-example for a ready to use example
application, but lets look into details and requirements.

In your mix.exs, add the dependency and the custom compiler for webpack: 
- Add the `:reaxt` dependency to your project.deps and application.applications
- Add `compilers: [:reaxt_webpack] ++ Mix.compilers` to your project

In your config/config.exs, link the reaxt application to the
application containing the JS web app
- `config :reaxt,:otp_app,:yourapp`

Create the good directory and file layout:
- `MIXROOT/web`
- `MIXROOT/web/package.json` containing your app NPM dependencies
- `MIXROOT/web/webpack.config.js` containing only the client side
  logic, use "reaxt/style" instead of "style" loader to load your css.
  A typical output path is `../priv/static`.
- `MIXROOT/web/components` containing modules exporting React components

In your elixir code generating HTML :
- add `WebPack.header` in the `<head>`
- add a script with src `/your/public/path/<%= WebPack.file_of(:entry_name) %>` 

Then render your server side HTML :

```elixir
# if web/components/thefile exports the react component
Reaxt.render!(:thefile,%{it: "is", the: "props"})

# if web/components/thefile exports an object containing a react component
# at the key "component_key"

Reaxt.render!({:thefile,:component_key},%{it: "is", the: "props"})
```

The function return a `%{html: html,css: css,js_render: js_render}`, you have to add in the html :
- the css `<style><%= render.css %></style>`
- the html in an identified block (`<div id="myblockid"><%= render.html %></div>`)
- the client side rendering call with `<script><%= render.js_render %>("myblockid")</script>`

For example, if you want a page entirely generated by the react
component exported at `web/components/app.js`, then in your elixir web server, send :

```elixir
EEx.eval_string("""
  <html>
  <head> <%= WebPack.header %>
    <style><%= render.css %></style>
  </head>
  <body>
    <div id="content"><%= render.html %></div>
    <script src="/public/<%= WebPack.file_of(:main) %>"></script>
    <script><%= render.js_render %>("content")</script>
  </body>
  </html>
""",render: Reaxt.render!(:app,%{my: "props"}))
```

Finally, you have to serve files generated by webpack :
```elixir
plug Plug.Static, at: "/public", from: :yourapp
```

Then `iex -S mix` and enjoy, but the best is to come.

## Custom Plug : Live reloading and WebPack web UI

When you serve files generated by webpack, use the plug
`WebPack.Plug.Static` instead of `Plug.Static`, it contains 
 an elixir implementation of
 [webpack-dev-server](https://www.npmjs.com/package/webpack-dev-server),
 and a [nice UI](http://webpack.github.io/analyse/).

```elixir
  if Mix.env == :dev do 
    use Plug.Debugger
    plug WebPack.Plug.Static, at: "/public", from: :myweb
  else
    plug Plug.Static, at: "/public", from: :myweb
  end
```

Then go to http://yourhost/webpack to see a beautiful summary of
your compiled js application.

Then configure in your application configuration :
- `config :reaxt,:hot,true` to enable that:
  - server and client side JS will be compiled each time you change files
  - server side renderers will be restarted at each compilation 
  - client browser page will be reloaded, a desktop notification will be triggered
  - The `/webpack` UI will be automatically reloaded if it is on your browser
- `config :reaxt,:hot,:client` to enable the same hot loading, but
  with webpack module hot loading on browser to avoid full page reload
  - use the webpack loader `react-hot-loader` to load your
    component to enable automatic browser hot reloading of your components
  - the `reaxt/style` loader for your css enable hot reloading of your css

## Dynamic Handler and customize rendering (useful with react-router)

Reaxt provides facilities to easily customize the rendering process at the
server and the client side : this is done by attaching `reaxt_server_render`
and/or `reaxt_client_render` to the module or object referenced by the first
argument of `Reaxt.render!(`.

- `reaxt_server_render(arg,callback)` will take `arg` from the second
  argument of `Reaxt.render`, and have to execute
  `callback(handler,props,param)` when the wanting handler and props
  are determined. `param` is any stringifyable object.
- `reaxt_client_render(props,elemid,param)` have to render the
  good selected component on the client side.

To understand how they work, let's look at the default implementation
of these functions (what happened when they are not implemented).

```javascript
// default server rendering only take the exported module as the
// handler to render and the argument as the props
default_reaxt_server_render = function(arg,callback){
  callback(this,arg)
}
// default client rendering only take the exported module as the
// handler to render, the param as the rendering context
default_reaxt_client_render = function(props,elemid,param){
  React.withContext(param, function() {
    React.render(React.createElement(this,props),document.getElementById(elemid))
  })
}
```

Now let's see an example usage of these functions : react-router
integration (`Reaxt.render` second argument is the Path):

```elixir
Reaxt.render!(:router_handler,full_path(conn))
```

```javascript
var App = require("./app")
var Router = require("react-router")
var Routes = require("./routes")
module.exports = {
  reaxt_server_render: function(path,callback){
    Router.run(Routes, path,function (Handler, state) {
      callback(Handler,{})
    })
  },
  reaxt_client_render: function(props,elemid){
    Router.run(Routes,Router.HistoryLocation,function(Handler,state){
      React.render(React.createElement(Handler,props),document.getElementById(elemid))
    })
  }
}
```

## Error management

JS exceptions and stacktraces during rendering are converted into
Elixir one with a fake stacktrace pointing to the generated javascript file.

This is really nice because you can see javascript stacktrace in the `Plug.Debugger` UI on exception.

## Perfs and pool management

The NodeJS renderers are managed in a pool (to obtain "multicore" JS rendering), so :

- `config :reaxt,:pool_size` configure the number of worker running permanently
- `config :reaxt,:pool_max_overflow` configure the maximum extension of the
  pool when query happens an it is full

A clever configuration could be : 

```elixir
config :reaxt,:pool_size, if(Mix.env == :dev, do: 1, else: 10)
```

For minification, remember that webpack compilation is launched by Mix, so you
can use `process.env.MIX_ENV` in your webpack config.

```elixir
{
  externals: { react: "React" },
  plugins: (function(){
    if(process.env.MIX_ENV == "prod") 
      return [new webpack.optimize.UglifyJsPlugin({minimize: true})]
    else
      return []
  })()
}
```
