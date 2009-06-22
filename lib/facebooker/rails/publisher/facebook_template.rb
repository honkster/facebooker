class Facebooker::Rails::Publisher::FacebookTemplate
  cattr_accessor :template_cache
  self.template_cache = {}

  def self.inspect(*args)
    "FacebookTemplate"
  end

  def template_changed?(hash)
    if respond_to?(:content_hash)
      content_hash != hash
    else
      false
    end
  end

  class << self
    def register(klass,method)
      publisher = setup_publisher(klass,method)
      template_id = Facebooker::Session.create.register_template_bundle(publisher.one_line_story_templates,publisher.short_story_templates,publisher.full_story_template,publisher.action_links)
      template = find_or_initialize_by_template_name(template_name(klass,method))
      template.bundle_id = template_id
      template.content_hash = hashed_content(klass,method) if template.respond_to?(:content_hash)
      template.save!
      cache(klass,method,template)
      template
    end

    def for_class_and_method(klass,method)
      find_cached(klass,method)
    end
    def bundle_id_for_class_and_method(klass,method)
      for_class_and_method(klass,method).bundle_id
    end

    def cache(klass,method,template)
      template_cache[template_name(klass,method)] = template
    end

    def clear_cache!
      self.template_cache = {}
    end

    def find_cached(klass,method)
      template_cache[template_name(klass,method)] || find_in_store(klass,method)
    end

    def setup_publisher(klass,method)
      publisher = klass.new
      publisher.send method + '_template'
      publisher
    end

    def hashed_content(klass, method)
      publisher = setup_publisher(klass,method)
      # sort the Hash elements (in the short_story and full_story) before generating MD5
      Digest::MD5.hexdigest [publisher.one_line_story_templates,
                             (publisher.short_story_templates and publisher.short_story_templates.collect{|ss| ss.to_a.sort_by{|e| e[0].to_s}}),
                             (publisher.full_story_template and publisher.full_story_template.to_a.sort_by{|e| e[0].to_s})
      ].to_json
    end

    def template_name(klass,method)
      "#{klass.name}::#{method}"
    end

    def find_in_store(klass, method)
      template = store.find_by_template_name(template_name(klass, method))
      if template and template.template_changed?(hashed_content(klass, method))
        template.destroy
        template = nil
      end

      if template.nil?
        template = register(klass, method)
      end
      template
    end

    def store
      @store ||= begin
        dir = File.dirname(__FILE__)
        require "#{dir}/active_record_store"
        Facebooker::Rails::Publisher::ActiveRecordStore
      end
    end
  end
end
