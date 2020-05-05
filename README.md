
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

### How to use

<details>
    <summary>Set up via docker</summary>

1. [Install and start cardano-wallet](https://github.com/input-output-hk/cardano-wallet/releases).

2. :point_down:
```
docker pull piotrstachyra/icarus:latest
docker run --network=host piotrstachyra/icarus:latest
```

</details>

or

<details>
    <summary>Set up from repository</summary>

1. [Install ruby](https://www.ruby-lang.org/en/documentation/installation/).

2. [Install and start cardano-wallet](https://github.com/input-output-hk/cardano-wallet/releases).

3. :point_down:
```
git clone https://github.com/piotr-iohk/icarus.git
cd icarus
bundle install
ruby app.rb
```

</details>

Good! Now go to http://localhost:4444/ and torture cardano-wallet with the web-app...


### Releasing

Releases have the same versions as [cardano-wallet](https://github.com/input-output-hk/cardano-wallet/releases) and should be compatible with them.

```bash
git tag -a v2020-04-28
git push origin --tags
```
