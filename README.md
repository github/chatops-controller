# ChatopsControllers

Rails helpers for JSON-RPC based easy chatops.

A minimal controller example:

```ruby
class ChatOpsController < ApplicationController
  include ::ChatOps::ControllerHelpers

  chatops_namespace :echo

  chatop :echo,
  /echo (?<text>.*)?/,
  "echo <text> - Echo some text back" do
    jsonrpc_success "Echoing back to you: #{jsonrpc_params[:text]}"
  end
end
```

Some routing boilerplate is required in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  post "/_chatops" => "chatops#execute"
  get  "/_chatops" => "chatops#list"
end
```

Next, tell hubot about your endpoint:

```
.rpc add https://myapp.githubapp.com/_chatops
```

You're all done. Try `.echo foo`, and you should see Hubot respond with `Echoing back to you: foo`.

## Usage

#### Namespaces

Every chatops controller has a namespace. All commands associated with this
controller will be displayed with `.help <namespace>`. Commands will also be
dispalyed with subsets of their text.

```
chatops_namespace :foo
```
#### Creating Chatops

Creating a chatop is a DSL:

```ruby
chatop :echo,
/echo (?<text>.*)?/,
"echo <text> - Echo some text back" do
  jsonrpc_success "Echoing back to you: #{jsonrpc_params[:text]}"
end
```

In this example, we've created a chatop called `echo`. The next argument is a
regular expression with [named
captures](http://ruby-doc.org/core-1.9.3/Regexp.html#method-i-named_captures).
In this example, only one capture group is available, `text`.

The next line is a string, which is a single line of help that will be displayed
in chat for `.help echo`.

The DSL takes a block, which is the code that will run when the chat robot sees
this regex. Arguments will be available in a hash called `jsonrpc_params`,
similar to rails' regular `params`.

You can return `jsonrpc_success` with a string to return text to chat. In this
case, we're just echoing the text back with a prefix.

TODO: chatops are not 'controller actions' and don't work with `before_filter`
like we'd want.

## Authentication

TODO: document this, but its god tokens.

## Development

```
script/bootstrap
script/test
```
