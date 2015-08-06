require 'spec_helper'

describe Her::JsonApi::Model do
  before do
    Her::API.setup :url => "https://api.example.com" do |connection|
      connection.use Her::Middleware::JsonApiParser
      connection.adapter :test do |stub|
        stub.get("/users/1") do |env|
          [
            200,
            {},
            {
              data: {
                id:    1,
                type: 'users',
                attributes: {
                  name: "Roger Federer",
                },
              }

            }.to_json
          ]
        end

        stub.get("/users") do |env|
          [
            200,
            {},
            {
              data: [
                {
                  id:    1,
                  type: 'users',
                  attributes: {
                    name: "Roger Federer",
                  },
                },
                {
                  id:    2,
                  type: 'users',
                  attributes: {
                    name: "Kei Nishikori",
                  },
                }
              ]
            }.to_json
          ]
        end

        stub.post("/users", data: {
          type: 'users',
          attributes: {
            name: "Jeremy Lin",
          },
        }) do |env|
          [
            201,
            {},
            {
              data: {
                id:    3,
                type: 'users',
                attributes: {
                  name: 'Jeremy Lin',
                },
              }

            }.to_json
          ]
        end

        stub.patch("/users/1", data: {
          type: 'users',
          id: 1,
          attributes: {
            name: "Fed GOAT",
          },
        }) do |env|
          [
            200,
            {},
            {
              data: {
                id:    1,
                type: 'users',
                attributes: {
                  name: 'Fed GOAT',
                },
              }

            }.to_json
          ]
        end

        stub.delete("/users/1") { |env|
          [ 204, {}, {}, ]
        }

        stub.get("/players") do |env|
          [
            200,
            {},
            {
              data: [
                {
                  id:    1,
                  type: 'players',
                  attributes: { name: "Roger Federer", },
                  relationships: {
                    sponsors: {
                      data: [
                        {
                          type: 'sponsors',
                          id: 1,
                        },
                        {
                          type: 'sponsors',
                          id: 2,
                        }
                      ]
                    },
                    racquet: {
                      data: {
                        type: 'racquets',
                        id: 1,
                      }
                    }
                  }
                },
                {
                  id:    2,
                  type: 'players',
                  attributes: { name: "Kei Nishikori", },
                  relationships: {
                    sponsors: {
                      data: [
                        {
                          type: 'sponsors',
                          id: 2,
                        },
                        {
                          type: 'sponsors',
                          id: 3,
                        }
                      ]
                    },
                    racquet: {
                      data: {
                        type: 'racquets',
                        id: 2,
                      }
                    }
                  }
                },
                {
                  id: 3,
                  type: 'players',
                  attributes: { name: 'Hubert Huang', racquet_id: 1 },
                  relationships: {}
                },
              ],
              included: [
                {
                  type: 'sponsors',
                  id: 1,
                  attributes: {
                    company: 'Nike',
                  }
                },
                {
                  type: 'sponsors',
                  id: 2,
                  attributes: {
                    company: 'Wilson',
                  },
                },
                {
                  type: 'sponsors',
                  id: 3,
                  attributes: {
                    company: 'Uniqlo',
                  },
                },
                {
                  type: 'racquets',
                  id: 1,
                  attributes: {
                    name: 'Wilson Pro Staff',
                  },
                },
                {
                  type: 'racquets',
                  id: 2,
                  attributes: {
                    name: 'Wilson Steam',
                  }
                },
              ]
            }.to_json
          ]
        end

        stub.get("/players/3/sponsors") do |env|
          [
            200,
            {},
            { data: [] }.to_json
          ]
        end
      end
    end

    spawn_model("Foo::User", Her::JsonApi::Model)
  end

  context 'simple jsonapi document' do
    it 'allows configuration of type' do
      spawn_model("Foo::Bar", Her::JsonApi::Model) do
        type :foobars
      end

      expect(Foo::Bar.instance_variable_get('@type')).to eql('foobars')
    end

    it 'finds models by id' do
      user = Foo::User.find(1)
      expect(user.attributes).to eql(
        'id' => 1,
        'name' => 'Roger Federer',
      )
    end

    it 'finds a collection of models' do
      users = Foo::User.all
      expect(users.map(&:attributes)).to match_array([
        {
          'id' => 1,
          'name' => 'Roger Federer',
        },
        {
          'id' => 2,
          'name' => 'Kei Nishikori',
        }
      ])
    end

    it 'creates a Foo::User' do
      user = Foo::User.new(name: 'Jeremy Lin')
      user.save
      expect(user.attributes).to eql(
        'id' => 3,
        'name' => 'Jeremy Lin',
      )
    end

    it 'updates a Foo::User' do
      user = Foo::User.find(1)
      user.name = 'Fed GOAT'
      user.save
      expect(user.attributes).to eql(
        'id' => 1,
        'name' => 'Fed GOAT',
      )
    end

    it 'destroys a Foo::User' do
      user = Foo::User.find(1)
      expect(user.destroy).to be_destroyed
    end

    context 'undefined methods' do
      it 'removes methods that are not compatible with json api' do
        [:parse_root_in_json, :include_root_in_json, :root_element, :primary_key].each do |method|
          expect { Foo::User.new.send(method, :foo) }.to raise_error NoMethodError, "Her::JsonApi::Model does not support the #{method} configuration option"
        end
      end
    end
  end

  context 'compound document' do
    before do
      spawn_model("Foo::Sponsor", Her::JsonApi::Model)
      spawn_model("Foo::Racquet", Her::JsonApi::Model)
      spawn_model("Foo::Player", Her::JsonApi::Model) do
        has_many :sponsors
        has_one :racquet
      end
    end

    it 'parses included documents into object if relationship specifieds a resource linkage' do
      players = Foo::Player.all.to_a
      fed = players.detect { |p| p.name == 'Roger Federer' }
      expect(fed.sponsors.map(&:company)).to match_array ['Nike', 'Wilson']
      expect(fed.racquet.name).to eq 'Wilson Pro Staff'

      kei = players.detect { |p| p.name == 'Kei Nishikori' }
      expect(kei.sponsors.map(&:company)).to match_array ['Uniqlo', 'Wilson']
      expect(kei.racquet.name).to eq 'Wilson Steam'

      hubert = players.detect { |p| p.name == 'Hubert Huang' }
      expect(hubert.sponsors.map(&:company)).to eq []
      expect(hubert.racquet.name).to be_nil
    end
  end
end
