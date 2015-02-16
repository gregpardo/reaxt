defmodule Mix.Tasks.Compile.Reaxt do
  def run(args) do
    if !File.exists?("web/node_modules") do
      Mix.Task.run("npm.install", args)
    else
      installed_version = Poison.decode!(File.read!("web/node_modules/reaxt/package.json"))["version"]
      current_version = Poison.decode!(File.read!("#{:code.priv_dir(:reaxt)}/commonjs_reaxt/package.json"))["version"]
      if  installed_version !== current_version, do:
        Mix.Task.run("npm.install", args)
    end

    if !Application.get_env(:reaxt,:hot), do:
      Mix.Task.run("webpack.compile", args)
  end
end
