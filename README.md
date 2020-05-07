
<a href="https://github.com/piotr-iohk/icarus/releases">
  <img src="https://img.shields.io/github/release/piotr-iohk/icarus.svg" />
</a>
<a href="https://github.com/piotr-iohk/icarus/actions?query=workflow%3A%22Linux+%7C+Windows+%7C+MacOS%22">
  <img src="https://github.com/piotr-iohk/icarus/workflows/Linux%20%7C%20Windows%20%7C%20MacOS/badge.svg" />
</a>
<a href="https://github.com/piotr-iohk/icarus/actions?query=workflow%3A%22Docker+Image+CI%22">
  <img src="https://github.com/piotr-iohk/icarus/workflows/Docker%20Image%20CI/badge.svg" />
</a>

# Icarus

A helper web-app and cli to test [cardano-wallet](https://github.com/input-output-hk/cardano-wallet).

## Quick start

```
wget https://raw.githubusercontent.com/piotr-iohk/icarus/master/docker-compose.yml
NETWORK=testnet docker-compose up
```

This immediately spins up:
 - cardano-node connected to `testnet`
 - cardano-wallet on port `8090`
 - icarus web-app on port `4444`

Visit http://localhost:4444/, click _Connect_ and play around!


## Alternative setup
Alternatively one can [set up cardano-wallet](https://github.com/input-output-hk/cardano-wallet/releases) with any of the supported block producer and start icarus on top of it:

<details>
    <summary>Via docker</summary>

```
docker pull piotrstachyra/icarus:latest
docker run --network=host piotrstachyra/icarus:latest
```

</details>

or

<details>
    <summary>From repository</summary>

1. [Have ruby](https://www.ruby-lang.org/en/documentation/installation/).
2.  :point_down:
```
git clone https://github.com/piotr-iohk/icarus.git
cd icarus
bundle install
ruby app.rb
```

</details>

Good! now visit http://localhost:4444/, click _Connect_ and play around!


## Releases

[Releases]([https://github.com/piotr-iohk/icarus/releases](https://github.com/piotr-iohk/icarus/releases)) have the same versions as [cardano-wallet](https://github.com/input-output-hk/cardano-wallet/releases) and should be compatible with them.
