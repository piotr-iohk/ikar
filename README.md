<a href="https://github.com/piotr-iohk/icarus/actions?query=workflow%3A%22Linux+%7C+Windows+%7C+MacOS%22">
  <img src="https://github.com/piotr-iohk/icarus/workflows/Linux%20%7C%20Windows%20%7C%20MacOS/badge.svg" />
</a>

# Icarus

A helper web-app and cli to test [cardano wallet backend](https://github.com/input-output-hk/cardano-wallet).

### To use

0. Have Cardano wallet backend running.

1. Have [ruby](https://www.ruby-lang.org/en/downloads/), e.g.:

```
sudo apt-get install ruby
```
or
```
yum install ruby
```
2. :point_down:
```
git clone https://github.com/piotr-iohk/icarus.git
cd icarus
bundle install
ruby app.rb
```
Go to http://localhost:4444/ and torture wallet-backend with the web-app...

... or play with the cli:
```
$ cli --help

Wallet test aid

Usage:
  ./cli [--conf=<co>] stats (new|old) [full] [<wid>]
  ./cli [--conf=<co>] stats stake-pools
  ./cli [--conf=<co>] stats jorm [stake] [logs]
  ./cli [--conf=<co>] create (new|old) <name>
  ./cli [--conf=<co>] create-many (new|old) <number>
  ./cli [--conf=<co>] del (new|old) <wid>
  ./cli [--conf=<co>] del-all (new|old)
  ./cli [--conf=<co>] test [same_addr] <wid1> <wid2> 
  ./cli [--conf=<co>] tx <wid1> <wid2>
  ./cli [--conf=<co>] join-sp <sp_id> <wid>  
  ./cli [--conf=<co>] quit-sp <sp_id> <wid>  
  ./cli config read [--conf=<co>]
  ./cli config gen [--conf=<co>] [--max-sleep=<sec>] [--max-tx-spend=<t>] [--port-new=<port>] [--pass=<pass>] [--port-jorm=<port>] 
  ./cli -h | --help

Args:
  stats (new|old)        Stats for new wallet (Shelley) or old wallet (Byron)
  stats stake-pools      List stake pools via wallet backend
  stats jorm             Stats for Jörmungandr node
  test [same_addr]       Run txs back and forth between 2 wallets <wid1> <wid2>
                         if same_addr provided uses the same address all the time, 
                         otherwise always picks some unused one
  tx                     Run 1 tx between 2 wallets <wid1> <wid2>
  create (new|old)       Create new wallet (Shelley) or old wallet (Byron)
  create-many (new|old)  Create many wallets (Shelley or Byron)
  del (new|old)          Delete new wallet (Shelley) or old wallet (Byron)
  del-all (new|old)      Delete all new wallets (Shelley) or old wallets (Byron)
  join-sp <sp_id> <wid>  Join stake-pool identified by stake-pool id <sp_id> 
                         with your wallet identified by wallet id <wid>
  quit-sp <sp_id> <wid>  Quit stake-pool identified by stake-pool id <sp_id> 
                         with your wallet identified by wallet id <wid>
  config                 Read or gen config file
  
Options:
  -h --help           Show this screen. 
  --conf=<co>         Path to config file [default: ./config.yml]
  --max-sleep=<sec>   Max sleep between two txs when testing [default: 0]
  --max-tx-spend=<t>  Max tx spend between two txs when testing [default: 0.00001]
  --port-new=<port>   New wallet's server port [default: 8090]
  --pass=<pass>       Password for wallets [default: Secure Passphrase]
  --port-jorm=<port>  Jormungandr node api port [default: 8080]

```

