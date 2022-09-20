<a href="https://github.com/piotr-iohk/ikar/releases">
  <img src="https://img.shields.io/github/release/piotr-iohk/ikar.svg" />
</a>
<a href="https://hub.docker.com/r/piotrstachyra/icarus">
  <img src="https://img.shields.io/docker/pulls/piotrstachyra/icarus.svg" />
</a>
<a href="https://github.com/piotr-iohk/ikar/actions?query=workflow%3ATests">
  <img src="https://github.com/piotr-iohk/ikar/workflows/Tests/badge.svg" />
</a>
<a href="https://github.com/piotr-iohk/ikar/actions?query=workflow%3ADocker">
  <img src="https://github.com/piotr-iohk/ikar/workflows/Docker/badge.svg" />
</a>

# Ikar

A helper web-app and cli to test [cardano-wallet](https://github.com/input-output-hk/cardano-wallet).

## Quick start

```
wget https://raw.githubusercontent.com/piotr-iohk/ikar/master/docker-compose.yml
NETWORK=mainnet docker-compose up
```

This immediately spins up:

- cardano-node connected to `mainnet`
- cardano-wallet on port `8090`
- ikar web-app on port `4444`

Visit http://localhost:4444/, click _Connect_ and play around!

 > :information_source: With Ikar you can also connect to `preview` and `preprod` testnets.
 > See [Cardano Book](https://book.world.dev.cardano.org/environments.html) for more information on environments.

## Setup

If you already have [cardano-wallet](https://github.com/input-output-hk/cardano-wallet) and [cardano-node](https://github.com/input-output-hk/cardano-node) set up on your machine, you can connect Ikar to the stack as follows:

<details>
    <summary>Via docker</summary>

```
docker pull piotrstachyra/icarus:latest
docker run --network=host --rm piotrstachyra/icarus:latest
```

</details>

or

<details>
    <summary>From repository</summary>

1. [Have ruby](https://www.ruby-lang.org/en/documentation/installation/).
2. :point_down:

```
git clone https://github.com/piotr-iohk/ikar.git
cd ikar
bundle config set without 'development test'
bundle install
ruby app.rb
```

</details>

or

<details>
    <summary>From repository with `nix`</summary>

Nix development shell provides required `ruby` and app depenencies.
This command starts app:

```
nix develop -c ruby app.rb
```

</details>

Good! now visit http://localhost:4444/, click _Connect_ and play around!

## Releases

[Releases](<[https://github.com/piotr-iohk/ikar/releases](https://github.com/piotr-iohk/ikar/releases)>) have the same versions as [cardano-wallet](https://github.com/input-output-hk/cardano-wallet/releases) and should be compatible with them.

## Developer Notes

Updating `Gemfile` requires regenerating `Gemfile.lock` and `gemset.nix`:
```ruby
bundle lock
nix run nixpkgs#bundix
```
