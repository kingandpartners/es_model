def insert_record(options)
  options[:index] = "es_model_test_#{options.fetch(:index)}"

  elasticsearch.index(options.reverse_merge(type: 'jsondata', refresh: true))
end

def es_params(index)
  {
    index: "es_model_test_#{index}",
    body: {
      mappings: {
        jsondata: {
          properties: {
            taxonomies: {
              type: 'nested'
            },
            ID: {
              type: 'keyword'
            },
            post_id: {
              type: 'keyword'
            }
          }
        }
      }
    }
  }
end

def elasticsearch
  EsModel::Model.elasticsearch
end

def create_page(id, status = 'publish')
  create_item('page', id, status)
end

def create_post(id, status = 'publish')
  create_item('post', id, status)
end

def create_item(type, id, status)
  insert_record(
    index: type,
    id: id.to_s,
    body: {
      post_status: status,
      post_name: "test-#{type}-#{id}",
      ID: id
    }
  )
  EsModel::Page.find_by(id: id)
end
