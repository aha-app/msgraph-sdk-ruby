require 'spec_helper'

describe MicrosoftGraph::ClassBuilder do
  describe ".load!" do
    Given(:service) { OData::Service.new(base_url: "https://graph.microsoft.com/v1.0/", namespace: "microsoft.graph", metadata_file: File.join(MicrosoftGraph::CACHED_METADATA_DIRECTORY, "metadata_v1.0.xml")) }
    When { MicrosoftGraph::ClassBuilder.load!(service) }
    Then { defined?(MicrosoftGraph::Entity) }

    context "entity type User" do
      describe "class" do
        Then { defined?(MicrosoftGraph::User) }
        Then { MicrosoftGraph::User.superclass == MicrosoftGraph::DirectoryObject }

        context "will tell you the odata type that defined it" do
          Then { OData::EntityType === MicrosoftGraph::User.odata_type }
          Then { MicrosoftGraph::User.odata_type.name == "microsoft.graph.user" }
        end
      end
      describe "instance" do
        When(:subject) { MicrosoftGraph::User.new }
        Then { subject.properties.length == 42 }
        Then { subject.respond_to?(:given_name) }

        context "inherits the id property" do
          Then { subject.respond_to?(:id) }
          Then { subject.id.nil? }
        end
      end
    end

    context "complex type Attendee" do
      Then { defined?(MicrosoftGraph::Attendee) }
      Then { MicrosoftGraph::Attendee.superclass == MicrosoftGraph::Recipient }
      Then { MicrosoftGraph::Attendee.new.respond_to?(:status) }
      Then { MicrosoftGraph::Attendee.new.respond_to?(:email_address) }
      Then { MicrosoftGraph::Attendee.new.properties.length == 3 }
    end
  end

  describe ".load! before anything is loaded" do
    let(:service) { OData::Service.new(base_url: "https://graph.microsoft.com/v1.0/", namespace: "microsoft.graph", metadata_file: File.join(MicrosoftGraph::CACHED_METADATA_DIRECTORY, "metadata_v1.0.xml")) }

    before { MicrosoftGraph::ClassBuilder.class_variable_set(:@@loaded, false) }
    after { MicrosoftGraph::ClassBuilder.class_variable_set(:@@loaded, true) }

    it "builds the classes once when several threads create their first graph" do
      created = Queue.new

      allow(MicrosoftGraph::ClassBuilder).to receive(:create_class!).and_wrap_original do |original, type|
        # Pause the first load so the other thread starts its own
        sleep(0.1) if created.empty?

        created << type.name
        original.call(type)
      end

      2.times.map { Thread.new { MicrosoftGraph::ClassBuilder.load!(service) } }.each(&:join)

      expect(created.size).to eq(service.entity_types.size + service.complex_types.size)
    end

    it "doesn't add to the service's entity sets each time navigation properties are read" do
      MicrosoftGraph::ClassBuilder.load!(service)

      graph = MicrosoftGraph.new(cached_metadata_file: File.join(MicrosoftGraph::CACHED_METADATA_DIRECTORY, "metadata_v1.0.xml"))
      entity_set_count = service.entity_sets.size

      2.times { graph.navigation_properties }

      expect(service.entity_sets.size).to eq(entity_set_count)
      expect(graph.navigation_properties.keys).to include(:users, :me)
    end
  end

  it 'has a version number' do
    expect(MicrosoftGraph::VERSION).not_to be nil
  end
end
