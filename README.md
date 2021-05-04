<div style="text-align:center"><img src="https://raw.githubusercontent.com/azutoolkit/topia/master/topia.png" /></div>

# Topia

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/7b3ae440bb144c08bfd38fa5056a697c)](https://www.codacy.com/gh/azutoolkit/topia/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=azutoolkit/topia&amp;utm_campaign=Badge_Grade) [![Crystal CI](https://github.com/azutoolkit/topia/actions/workflows/crystal.yml/badge.svg)](https://github.com/azutoolkit/topia/actions/workflows/crystal.yml)


## A toolkit to automate & enhance your workflow

Leverage Topia and the flexibility of Crystal to automate mundane, repetitive tasks and compose them into efficient automated build pipelines.

Topia allows you to use existing Crystal knowledge to write workflows in plain Crystal code. With built in utilities are provided to simplify working with the filesystem and command line, everything else you write is pure Crystal.

### Flexible

Using code over configuration, utilize all of Crystal to create your workflow—where tasks can be written using your own code or chained single purpose plugins.

Run your own cli tool easily

```bash
~/workspaces/topia master*
❯ ./topia azu.endpoint dashboad_home get:/dashboard/:name request response
✓ Task 'azu.endpoint' finished successfully.
```

### Composable

Write individual, focused tasks and compose them into larger operations, providing you with speed and accuracy while reducing repetition.

```crystal
require "../src/topia"
require "./tasks/*"

support_dir = "../spec/support"

Topia.task("azu.endpoint")
  .pipe(Generator.new)
  .command("mkdir -p ./playground/endpoints")

Topia::CLI.run
```

### Efficient

By using Topia streams, you can apply many transformations to your files while in memory before anything is written to the disk—significantly speeding up your build process.

### Extensible

Using community-built plugins is a quick way to get started with Topia. Each plugin does a small amount of work, so you can connect them like building blocks. Chain together plugins from a variety of technologies to reach your desired result.

```crystal
class Generator
  include Topia::Plugin

  def run(input, params)
    announce "Generating Endpoint!"
    name, route, request, response = params
    method, path = route.split(":/")
    
    File.open("./playground/endpoints/#{name.downcase}.cr", "w") do |file|
      file.puts <<-CONTENT
      class #{name.camelcase}Endpoint
        include Azu::Endpoint(#{request.camelcase}, #{response.camelcase})
        
        #{method.downcase} "/#{path.downcase}"

        def call : #{response.camelcase}
        end
      end
      CONTENT
    end
    announce "Done Generating Endpoint!"
    true
  end

  def on(event : String)
    announce " Hello from event: #{event}"
  end
end
```

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     topia:
       github: azutoolkit/topia
   ```

2. Run `shards install`

## Usage

```crystal
require "topia"
```

### Compose tasks

Topia provides two powerful composition methods, allowing individual tasks to be composed into larger operations.

```crystal
require "topia"
require "topia/plugins/*"

# Register tasks

Topia.task("hello-world")
  .src("./text-files/*.txt")
  .pipe(elloWorld.new)
  .dist("./text-files")
```

## Development

- [ ] Add Asynchronous tasks

## Contributing

1. Fork it (<https://github.com/azutoolkit/topia/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Elias J. Perez](https://github.com/eliasjpr) - creator and maintainer
