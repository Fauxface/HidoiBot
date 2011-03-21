# encoding:utf-8
# Ported from HidoiBot1
class JapaneseToRomanji < BotPlugin
    def initialize
        # Authorisations
        @reqJpToRomAuth = 0
    
        # Required plugin stuff
        name = self.class.name
        hook = 'jptorom'
        processEvery = false
        help = "Usage: #{hook} <term>\nFunction: Converts Hiragana and Katakana in term to Romanji."
        super(name, hook, processEvery, help)
    end

    def main(data)
        @givenLevel = data["authLevel"]
        requiredLevel = @reqJpToRomAuth
        
        if authCheck(requiredLevel)
            termToTranslate = stripTrigger(data)
            return sayf(hiraToRom(termToTranslate))
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def hiraToRom(translate)
        # Not the best design, I know, but I couldn't bear myself to do all the input again
        translate.force_encoding("UTF-8")
        
        # Diagraphs before Hiragana
        hirakataList = [
            # Hiragana diagraphs
            "くゎ", "きゃ", "きゅ", "きょ", "しゃ", "しゅ", "しょ", "ちゃ", "ちゅ", "ちょ",
            "にゃ", "にゅ", "にょ", "ひゃ", "ひゅ", "ひょ", "みゃ", "みゅ", "みょ", "りゃ",
            "りゅ", "りょ", "ぐゎ", "ぎゃ",  "ぎゅ", "ぎょ", "じゃ", "じゅ", "じょ", "ぢゃ",
            "ぢゅ", "ぢょ", "びゃ", "びゅ", "びょ", "ぴゃ", "ぴゅ", "ぴょ",
            
            # Katakana diagraphs
            "キャ", "キュ", "キョ", "シャ", "シュ", "ショ", "チャ", "チュ", "チョ", "ニャ",
            "ニュ", "ニョ", "ヒャ", "ヒュ", "ヒョ", "ミャ", "ミュ", "ミョ", "リャ", "リュ",
            "リョ", "ギャ", "ギュ", "ギョ", "ジャ", "ジュ", "ジョ", "ヂャ", "ヂュ", "ヂョ",
            "ビャ", "ビュ", "ビョ", "ピャ", "ピュ", "ピョ",

            # Extended Katakana
            "イィ", "イェ", "ウァ", "ウィ", "ウゥ", "ウェ", "ウォ", "ウュ", "ヴァ", "ヴィ",
            "ヴ", "ヴェ", "ヴォ", "ヴャ", "ヴュ", "ヴョ", "キェ", "ギェ", "クァ", "クィ",
            "クェ", "クォ", "グァ", "グィ", "グェ", "グォ", "シェ", "ジェ", "スィ", "ズィ",
            "チェ", "ツァ", "ツィ", "ツェ", "ツォ", "ツュ", "ティ", "トゥ", "テュ", "ディ",
            "ドゥ", "デュ", "ニェ", "ヒェ", "ビェ", "ピェ", "ファ", "フィ", "フェ", "フォ",
            "フャ", "フュ", "フュ", "フィェ", "ホゥ", "ミェ", "リェ", "ラ゜", "リ゜", "ル゜",
            "レ゜", "ロ゜",
            
            # Specials
            "っ", "ゝ", "ゞ",
            "ー", "ヽ", "ヾ", "ッ",
            
            # Hiragana
            "あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ",
            "が", "ざ", "だ", "ば", "ぱ", "い", "き", "し", "ち", "に",
            "ひ", "み", "り", "ゐ", "ぎ", "じ", "ぢ", "び", "ぴ", "う",
            "く", "す", "つ", "ぬ", "ふ", "む", "ゆ", "る", "ぐ", "ず",
            "ぶ", "ぷ", "え", "け", "せ", "て", "ね", "へ", "め", "れ",
            "ゑ", "げ", "ぜ", "で", "べ", "ぺ", "お", "こ", "そ", "と",
            "の", "ほ", "も", "よ", "ろ", "を", "ご", "ぞ", "ど", "ぼ",
            "ぽ", "ん", "ゔ", "づ",
            
            # Katakana
            "ア", "イ", "ウ", "エ", "オ", "カ", "キ", "ク", "ケ", "コ",
            "サ", "シ", "ス", "セ", "ソ", "タ", "チ", "ツ", "テ", "ト",
            "ナ", "ニ", "ヌ", "ネ", "ノ", "ハ", "ヒ", "フ", "ヘ", "ホ",
            "マ", "ミ", "ム", "メ", "モ", "ヤ", "ユ", "ヨ", "ラ", "リ",
            "ル", "レ", "ロ", "ワ", "ヰ", "ヱ", "ヲ", "ン", "ガ", "ギ",
            "グ", "ゲ", "ゴ", "ザ", "ジ", "ズ", "ゼ", "ゾ", "ダ", "ヂ",
            "ヅ", "デ", "ド", "バ", "ビ", "ブ", "ベ", "ボ", "パ", "ピ",
            "プ", "ペ", "ポ",

            # Punctuation
            "、", "。"
        ]
        
        romanjiList = [
            # Romanji for Hiragana diagraphs
            "kwa", "kya", "kyu", "kyo", "sha", "shu", "sho", "cha", "chu", "cho",
            "nya", "nyu", "nyo", "hya", "hyu", "hyo", "mya", "myu", "myo", "rya",
            "ryu", "ryo", "gwa", "gya", "gyu", "gyo", "ja", "ju", "jo", "ja",
            "ju", "jo", "bya", "byu", "byo", "pya", "pyu", "pyo",
            
            # Romanji for Katakana diagraphs
            "kya", "kyu", "kyo", "sha", "shu", "sho", "cha", "chu", "cho", "nya",
            "nyu", "nyo", "hya", "hyu", "hyo", "mya", "myu", "myo", "rya", "ryu",
            "ryo", "gya", "gyu", "gyo", "ja", "ju", "jo", "ja", "ju", "jo",
            "bya", "byu", "byo", "pya", "pyu", "pyo",
            
            # Extended Katakana
            "yi", "ye", "wa", "wi", "wu", "we", "wo", "wyu", "va", "vi",
            "vu", "ve", "vo", "vya", "vyu", "vyo", "kye", "gye", "kwa", "kwi",
            "kwe", "kwo", "gwa", "gwi", "gwe", "gwo", "she", "je", "si", "zi",
            "che", "tsa", "tsi", "tse", "tso", "tsyu", "ti", "tu", "tyu", "di",
            "du", "dyu", "nye", "hye", "bye", "pye", "fa", "fi", "fe", "fo",
            "fya", "fyu", "fyo", "fye", "hu", "mye", "rye", "la", "li", "lu",
            "le", "lo",
            
            # Specials
            "(emp)", "(x2)", "(ゞ)", 
            "(emp)", "(x2)", "(ヾ)", "(emp)",
            
            # Romanji for Hiragana
            "a", "ka", "sa", "ta", "na", "ha", "ma", "ya", "ra", "wa",
            "ga" ,"za", "da", "ba", "pa", "i", "ki", "shi", "chi", "ni",
            "hi", "mi", "ri", "wi", "gi", "ji", "(ji)", "bi", "pi", "u",
            "ku", "su", "tsu", "nu", "fu", "mu", "yu", "ru", "gu", "zu",
            "bu", "pu", "e", "ke", "se", "te", "ne", "he", "me", "re",
            "we", "ge", "ze", "de", "be", "pe", "o", "ko", "so", "to",
            "no", "ho", "mo", "yo", "ro", "wo", "go", "zo", "do", "bo",
            "po", "n", "vu", "zu",
            
            # Romanji for Katakana
            "a", "i", "u", "e", "o", "ka", "ki", "ku", "ke", "ko",
            "sa", "shi", "su", "se", "so", "ta", "chi", "tsu", "te", "to",
            "na", "ni", "nu", "ne", "no", "ha", "hi", "fu", "he", "ho",
            "ma", "mi", "mu", "me", "mo", "ya", "yu", "yo", "ra", "ri",
            "ru", "re", "ro", "wa", "wi", "we", "wo", "n", "ga", "gi",
            "gu", "ge", "go", "za", "ji", "zu", "ze", "zo", "da", "ji",
            "zu", "de", "do", "ba", "bi", "bu", "be", "bo", "pa", "pi",
            "pu", "pe", "po",
            
            # Punctuation
            ",", "."
        ]

        reply = String.new
        skip = 0
        
        for i in 0..(translate.length)
            if skip == 0
                translationFound = 0
                for x in 0..hirakataList.length - 1
                    oldReply = reply
                    if translate [i+1] != nil && translate[i..i+1] == hirakataList[x]
                        # Diagraph checking
                        translationFound = 1
                        skip = 1
                        reply = reply + romanjiList[x]
                    elsif translate[i] == hirakataList[x] && translationFound == 0
                        # Checking the rest
                        translationFound = 1
                        reply = reply + romanjiList[x]
                    end	
                end
                
                if translationFound == 0
                    # If no translation was found and no changes were made, it is not a Japanese character
                    if oldReply == reply && translate [i] != nil
                        reply = reply + translate[i]
                    end
                end
            elsif skip > 0
                # Skips characters for diagraphs
                skip -= 1
            end
        end
        
        # Emphasis for consonants
        reply.gsub!(/\(emp\)(.)/, '\1\1')
        return reply
    rescue => e
        handleError(e)
        return e
	end
end