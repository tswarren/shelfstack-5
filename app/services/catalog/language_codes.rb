# frozen_string_literal: true

module Catalog
  # Curated ISO 639-2/T alpha-3 language codes for Product.language_code
  # (OD-P8-10 revision). Not a full ISO dump — retail-oriented set with
  # alpha-2 / BCP-47 mapping for provider imports.
  module LanguageCodes
    DEFAULT = "eng"

    # English display name => ISO 639-2/T code. Sorted by name; eng is also DEFAULT.
    PAIRS = [
      [ "Afrikaans", "afr" ],
      [ "Albanian", "sqi" ],
      [ "Arabic", "ara" ],
      [ "Armenian", "hye" ],
      [ "Basque", "eus" ],
      [ "Bengali", "ben" ],
      [ "Bulgarian", "bul" ],
      [ "Catalan", "cat" ],
      [ "Chinese", "zho" ],
      [ "Croatian", "hrv" ],
      [ "Czech", "ces" ],
      [ "Danish", "dan" ],
      [ "Dutch", "nld" ],
      [ "English", "eng" ],
      [ "Estonian", "est" ],
      [ "Finnish", "fin" ],
      [ "French", "fra" ],
      [ "Georgian", "kat" ],
      [ "German", "deu" ],
      [ "Greek", "ell" ],
      [ "Hebrew", "heb" ],
      [ "Hindi", "hin" ],
      [ "Hungarian", "hun" ],
      [ "Icelandic", "isl" ],
      [ "Indonesian", "ind" ],
      [ "Irish", "gle" ],
      [ "Italian", "ita" ],
      [ "Japanese", "jpn" ],
      [ "Korean", "kor" ],
      [ "Latin", "lat" ],
      [ "Latvian", "lav" ],
      [ "Lithuanian", "lit" ],
      [ "Malay", "msa" ],
      [ "Norwegian", "nor" ],
      [ "Persian", "fas" ],
      [ "Polish", "pol" ],
      [ "Portuguese", "por" ],
      [ "Romanian", "ron" ],
      [ "Russian", "rus" ],
      [ "Serbian", "srp" ],
      [ "Slovak", "slk" ],
      [ "Slovenian", "slv" ],
      [ "Spanish", "spa" ],
      [ "Swahili", "swa" ],
      [ "Swedish", "swe" ],
      [ "Thai", "tha" ],
      [ "Turkish", "tur" ],
      [ "Ukrainian", "ukr" ],
      [ "Urdu", "urd" ],
      [ "Vietnamese", "vie" ],
      [ "Welsh", "cym" ],
      [ "Yiddish", "yid" ]
    ].freeze

    OPTIONS = PAIRS.map { |name, code| [ "#{name} (#{code})", code ] }.freeze
    CODES = PAIRS.map(&:last).freeze
    LABEL_BY_CODE = PAIRS.to_h { |name, code| [ code, "#{name} (#{code})" ] }.freeze

    # ISO 639-1 alpha-2 → curated ISO 639-2/T (only codes in CODES).
    ALPHA2_TO_ALPHA3 = {
      "af" => "afr",
      "sq" => "sqi",
      "ar" => "ara",
      "hy" => "hye",
      "eu" => "eus",
      "bn" => "ben",
      "bg" => "bul",
      "ca" => "cat",
      "zh" => "zho",
      "hr" => "hrv",
      "cs" => "ces",
      "da" => "dan",
      "nl" => "nld",
      "en" => "eng",
      "et" => "est",
      "fi" => "fin",
      "fr" => "fra",
      "ka" => "kat",
      "de" => "deu",
      "el" => "ell",
      "he" => "heb",
      "hi" => "hin",
      "hu" => "hun",
      "is" => "isl",
      "id" => "ind",
      "ga" => "gle",
      "it" => "ita",
      "ja" => "jpn",
      "ko" => "kor",
      "la" => "lat",
      "lv" => "lav",
      "lt" => "lit",
      "ms" => "msa",
      "no" => "nor",
      "nb" => "nor",
      "nn" => "nor",
      "fa" => "fas",
      "pl" => "pol",
      "pt" => "por",
      "ro" => "ron",
      "ru" => "rus",
      "sr" => "srp",
      "sk" => "slk",
      "sl" => "slv",
      "es" => "spa",
      "sw" => "swa",
      "sv" => "swe",
      "th" => "tha",
      "tr" => "tur",
      "uk" => "ukr",
      "ur" => "urd",
      "vi" => "vie",
      "cy" => "cym",
      "yi" => "yid"
    }.freeze

    module_function

    def normalize(raw)
      return nil if raw.blank?

      value = raw.to_s.strip.downcase.gsub(/\s+/, "")
      return nil if value.blank?
      return value if CODES.include?(value)

      primary = value.split(/[-_]/, 2).first
      return primary if CODES.include?(primary)

      mapped = ALPHA2_TO_ALPHA3[primary]
      return mapped if mapped && CODES.include?(mapped)

      nil
    end

    def label_for(code)
      return nil if code.blank?

      LABEL_BY_CODE[code.to_s] || code.to_s
    end
  end
end
