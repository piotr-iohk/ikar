require 'httparty'
require 'bip_mnemonic'

class OldWalletBackend
  include HTTParty
  attr_accessor :wid, :account_id, :port

  def initialize(port)
    @account_id = 2147483648
    @port = port
    @api = "https://localhost:#{port}/api/v1"
  end

  def delete(id)
    self.class.delete("#{@api}/wallets/#{id}", verify: false)
  end

  def wallets
    self.class.get("#{@api}/wallets", verify: false)
  end

  def wallets_ids
    wallets['data'].map { |w| w['id'] }
  end

  def wallet (id)
    self.class.get("#{@api}/wallets/#{id}", verify: false)
  end

  def wallet_balance (id)
    wallet(id)['data']['balance']
  end

  def address_create (id, pass = "")
    self.class.post("#{@api}/addresses",
      :body => { :accountIndex => @account_id,
                 :walletId => id,
                 :spendingPassword => pass  }.to_json,
      :headers => { 'Content-Type' => 'application/json' },
      :verify => false )['data']['id']
  end

  def create_transaction(amount, address, id, pass = "")

    self.class.post("#{@api}/transactions",
      :body => { :groupingPolicy => "OptimizeForHighThroughput",
                 :destinations => [ { :amount => amount, :address => address } ],
                 :source => { :accountIndex => @account_id, :walletId => id },
                 :spendingPassword => pass  }.to_json,
      :headers => { 'Content-Type' => 'application/json' },
      :verify => false )
  end

  def create_wallet(name, mnemonics, pass)
    self.class.post("#{@api}/wallets",
      :body => { :operation => "create",
                 :backupPhrase => mnemonics,
                 :assuranceLevel => "strict",
                 :name => name,
                 :spendingPassword => pass  }.to_json,
      :headers => { 'Content-Type' => 'application/json' },
      :verify => false )
  end

end

ow = OldWalletBackend.new "36291"
ow.wallets_ids.each do |id|
  ow.delete id if id != "Ae2tdPwUPEYw3WFC6g6sMo76uPq314Fd3CA8k2zpkJF1QEXBjNEMgdLgPBj"
end
mems = BipMnemonic.to_mnemonic(bits: 128, language: 'english')
puts mems
puts ow.create_wallet "new wallet", mems.split, ""
# wallets =
#   [ "АаБбВвГгДдЕеЁёЖжЗз ИиЙйКкЛлМмНнО оПпРрСсТтУуФф ХхЦцЧчШшЩщЪъ ЫыЬьЭэЮюЯяІ ѢѲѴѵѳѣі", "aąbcćdeęfghijklłmnoóprsś\r\ntuvwyzżźAĄBCĆDEĘFGHIJKLŁMNOP\rRSŚTUVWYZŻŹ", "ثم نفس سقطت وبالتحديد،, جزيرتي باستخدام أن دنو. إذ هنا؟ الستار وتنصيب كان. أهّل ايطاليا، بريطانيا-فرنسا قد أخذ. سليمان، إتفاقية بين ما, يذكر الحدود أي بعد, معاملة بولندا، الإطلاق عل إيو.", "亜哀挨愛曖悪握圧扱宛嵐安案暗以衣位囲医依委威為畏胃尉異移萎偉椅彙意違維慰\
#   \遺緯域育一壱逸茨芋引印因咽姻員院淫陰飲隠韻右宇羽雨唄鬱畝浦運雲永泳英映栄\n営詠影鋭衛易疫益液駅悦越謁\
#   \閲円延沿炎怨宴媛援園煙猿遠鉛塩演縁艶汚王凹\r\n央応往押旺欧殴桜翁奥横岡屋億憶臆虞乙俺卸音恩温穏下化火加\
#   \可仮何花佳価果河苛科架夏家荷華菓貨渦過嫁暇禍靴寡歌箇稼課蚊牙瓦我画芽賀雅餓介回灰会快戒改怪拐悔海界\
#   \皆械絵開階塊楷解潰壊懐諧貝外劾害崖涯街慨蓋該概骸垣柿各角拡革格核殻郭覚較隔閣確獲嚇穫学岳楽額顎掛潟\
#   \括活喝渇割葛滑褐轄且株釜鎌刈干刊甘汗缶\r","`~`!@#$%^&*()_+-=<>,./?;':\"\"'{}[]\\|❤️ 💔 💌 💕 💞 \
#   \💓 💗 💖 💘 💝 💟 💜 💛 💚 💙0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟🇺🇸🇷🇺🇸 🇦🇫🇦🇲🇸"]
# wallets.each do |w|
#   mnems = BipMnemonic.to_mnemonic(bits: 128, language: 'english').split
#   puts ow.create_wallet w, mnems, "0202010002000102020002010202010002020100000102020201020000020102"
# end
