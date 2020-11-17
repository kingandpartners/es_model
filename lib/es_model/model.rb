require "ostruct"
require "active_support"
require "active_support/core_ext/hash/reverse_merge"
require "faraday_middleware/aws_sigv4"

class EsModel::Model < OpenStruct

  @@site_prefix = ENV.fetch('ES_SITE_PREFIX')

  # arbitrarily large number to search to return "all"
  MAX_RESULTS = 10_000
  SITE_ENV = ENV.fetch('ES_SITE_ENV')

  def self.set_site_prefix(prefix)
    @@site_prefix = prefix
  end

  def self.site_index_name
    index_name.gsub('SITE_ID', @@site_prefix)
  end

  def self.search(query)
    hits = elasticsearch.search(
      index: site_index_name,
      size: MAX_RESULTS,
      body: {
        query: {
          bool: {
            should: [
              { query_string: { query: "*#{query}*" } },
              {
                nested: {
                  path: :taxonomies,
                  query: {
                    bool: {
                      must: [
                        {
                          match: { "taxonomies.name" => query }
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        }
      }
    )['hits']['hits']

    hits.map do |data|
      new(data['_source'])
    end
  end

  def self.all
    hits = elasticsearch.search(
      index: site_index_name,
      size: MAX_RESULTS,
      body: { query: { term: { post_status: 'publish' } } }
    )['hits']['hits']

    hits.map do |data|
      new(data['_source'])
    end
  end

  def self.find(id)
    record = elasticsearch.get_source(index: site_index_name, id: id)

    unless record
      raise RecordNotFound, "Couldn't find #{name} with id #{id.inspect}"
    end

    new(record)
  end

  def self.find_by_slug(slug)
    results = elasticsearch.search(
      index: site_index_name, size: 1,
      body: term_filter(post_name: slug)
    )
    record = results['hits']['hits'].first
    unless record
      raise RecordNotFound, "Couldn't find #{name} with slug #{slug.inspect}"
    end
    new(record['_source'])
  end

  def self.find_by_url(input)
    record = nil
    urls = ["#{input}/", input]
    urls.each do |url|
      results = elasticsearch.search(
        index: site_index_name, size: 1,
        body: term_filter(url: url)
      )

      record = results['hits']['hits'].first
      break if record
    end

    unless record
      raise RecordNotFound, "Couldn't find #{name} with slug #{input.inspect}"
    end

    if record['_source']['page_template'] === "template-listings-single"
      Listing.new(record['_source'])
    else
      new(record['_source'])
    end
  end

  def self.by_taxonomy(taxonomy:, slug:)
    where(post_status: 'publish', taxonomies: { taxonomy: taxonomy, slug: slug })
  end

  def self.where(params)
    # remove empty params
    params.delete_if { |k,v| !v.present? }
    return [] if !params.present?
    params.merge!(post_status: params.fetch(:post_status, 'publish'))

    params = params.map do |k, v|
      if k.downcase.to_s.include?('id')
        v.is_a?(Array) ? [k, v.map(&:to_i)] : [k, v.to_i]
      else
        [k, v]
      end
    end

    or_params = params.select { |k, v| v.is_a?(Array) }
    and_params = params.select { |k, v| !v.is_a?(Array) }
    id_params = params.select { |k, v| k.downcase.to_s.include?('id') }
    sort_param = id_params.detect { |k, v| v.is_a?(Array) }
    query = { bool: {} }

    if or_params.any?
      query[:bool].merge!(
        should: or_params.map do |k, v|
          Array(v).map {|value| map_param(k, value) }
        end,
        minimum_should_match: 1
      )
    end

    if and_params.any?
      query[:bool].merge!(must: and_params.map { |k, v| map_param(k, v) })
    end

    body = { query: query }

    if sort_param.present?
      key, ids = sort_param
      script = painless_script(key)
      body.merge!(
        sort: [{
          _script: {
            type: 'number',
            script: {
              lang: 'painless',
              source: script,
              params: {
                ids: ids
              }
            },
            order: 'asc'
          }
        }]
      )
    end

    hits = elasticsearch.search(
      index: site_index_name,
      size: MAX_RESULTS,
      body: body
    )['hits']['hits']

    hits.map do |data|
      new(data['_source'])
    end
  end

  def self.painless_script(key)
    <<-SOURCE.strip_heredoc
      int id = Integer.parseInt(doc['#{key}'].value);
      List ids = params.ids;
      for (int i = 0; i < ids.length; i++) {
        if (ids.get(i) == id) { return i; }
      }
      return 100000;
    SOURCE
  end

  def self.find_by(params)
    if params.keys.include?(:id)
      record = elasticsearch.get_source(index: site_index_name, id: params[:id])
      record ? new(record) : nil
    else
      where(params).first
    end
  end

  def initialize(data)
    structs = data.transform_values { |val| convert_to_ostruct(val) }

    super(structs)
  end

  def self.elasticsearch
    @elasticsearch ||= begin
      Elasticsearch::Client.new(url: ENV.fetch('ES_URL')) do |f|
        if ENV.fetch('AWS_REGION', nil)
          f.request :aws_sigv4,
            service: 'es',
            region: ENV.fetch('AWS_REGION'),
            access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
            secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY')
        end
      end
    end
  end

  def deep_to_h(obj = nil)
    obj = obj || self
    return obj unless obj.is_a?(OpenStruct)
    obj.to_h.transform_values do |v|
      case v
      when OpenStruct
        deep_to_h(v)
      when Array
        v.map { |val| deep_to_h(val) }
      else
        v
      end
    end
  end

  private

  def convert_to_ostruct(value)
    case value
    when Hash
      OpenStruct.new(value.transform_values { |val| convert_to_ostruct(val) })
    when Array
      value.map { |val| convert_to_ostruct(val) }
    else
      value
    end
  end

  private_class_method def self.index_name=(name)
    @index_name = "SITE_ID_#{SITE_ENV}_#{name}"
  end

  private_class_method def self.indexes=(index_array)
    prefix = "SITE_ID_#{SITE_ENV}_"
    @index_name = index_array.map { |index| "#{prefix}#{index}" }.join(',')
  end

  private_class_method def self.index_name
    @index_name || (raise ArgumentError, 'Models must specify an index')
  end

  private_class_method def self.term_filter(terms)
    {
      query: {
        # Add .keyword to field name for exact matching
        term: terms.transform_keys { |key| "#{key}.keyword" }
      }
    }
  end

  private_class_method def self.map_param(key, value)
    if value.is_a?(Hash)
      {
        nested: {
          path: key,
          query: {
            bool: {
              must: value.map do |k, v|
                k = v.is_a?(Integer) ? k : "#{k}.keyword"
                { match: { "#{key}.#{k}" => v } }
              end
            }
          }
        }
      }
    else
      key = value.is_a?(Integer) ? key : "#{key}.keyword"
      { term: { key => value } }
    end
  end

  private_class_method def self.map_hits(results)
    hits = results['hits']['hits']

    hits.map do |data|
      new(data['_source'])
    end
  end

  RecordNotFound = Class.new(EsModel::Error)
end
