defmodule Mix.Tasks.Npm.Install do
  @shortdoc "`npm install` in web_dir + npm install server side dependencies"
  def run(_args) do
    System.cmd("npm",["install"], into: IO.stream(:stdio, :line), cd: "web")
    System.cmd("npm",["install","#{:code.priv_dir(:reaxt)}/commonjs_reaxt"], into: IO.stream(:stdio, :line), cd: "web")
  end
end
