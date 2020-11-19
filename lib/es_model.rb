require "ostruct"
require "elasticsearch"

module EsModel
  class Error < StandardError; end

  def self.root
    File.dirname __dir__
  end

end

require "es_model/model"
require "es_model/models/nav_menu"
require "es_model/models/option"
require "es_model/models/page"
require "es_model/models/post"
require "es_model/version"