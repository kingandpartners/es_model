RSpec.describe EsModel do

    let(:indices) do
      %w[
        page
        post
      ]
    end
  
    before do
      elasticsearch.indices.delete(index: "es_model_test_*")
  
      indices.each do |index|
        elasticsearch.indices.create(es_params(index))
      end
    end
  
    after do
      indices.each do |index|
        elasticsearch.indices.delete(index: "es_model_test_#{index}")
      end
    end

    describe ".all" do

      let!(:page) { create_page(1) }
      let!(:post) { create_post(2) }
  
      it "returns all page records" do
        expect(EsModel::Page.all).to eq([page])
      end

      it "does not include post" do
        expect(EsModel::Page.all).not_to include(post)
      end

    end
  
  end
  