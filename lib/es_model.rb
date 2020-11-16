require "ostruct"
require "elasticsearch"

module EsModel
  class Error < StandardError; end

  def self.root
    File.dirname __dir__
  end

end

require "es_model/version"
require "es_model/model"
require "es_model/models/page"
require "es_model/models/post"