require 'test_helper'

class TestTracking < MiniTest::Unit::TestCase
  def test_defining_instance_options
    @article = article.new
    # TODO: test :owner on real object
    options = {:key => 'key', :params => {:a => 1}}
    @article.activity(options)
    assert_equal(options[:key], @article.activity_key)
    #assert_equal(@article.activity_owner, options[:owner])
    assert_equal(options[:params], @article.activity_params)
    @article.save
    assert_equal(options[:key], @article.activities.last.key)
    #assert_equal(@article.activities.last.owner, options[:owner])
    assert_equal(options[:params], @article.activities.last.parameters)
  end

  def test_creating_activity
    klass = article
    @article = klass.new
    @article.activity :key => 'test'
    @article.save
    assert_equal 'test', @article.activities.last.key
  end

  def test_tracked_options_skip_defaults
    options = {:skip_defaults => true}
    klass = article(options)
    assert_includes klass.included_modules, PublicActivity::Common
  end

  def test_tracked_options_none
    klass = article
    assert_includes klass.included_modules, PublicActivity::Creation
    assert_includes klass.included_modules, PublicActivity::Destruction
    assert_includes klass.included_modules, PublicActivity::Update
    refute_empty klass._create_callbacks.select {|c| c.kind.eql?(:after) && c.filter == :activity_on_create }
    refute_empty klass._update_callbacks.select {|c| c.kind.eql?(:after) && c.filter == :activity_on_update }
    refute_empty klass._destroy_callbacks.select {|c| c.kind.eql?(:before) && c.filter == :activity_on_destroy }
  end

  def test_tracked_options_except
    options = {:except => [:create]}
    klass = article(options)
    assert_includes options[:only], :destroy
    assert_includes options[:only], :update
    refute_includes options[:only], :create
    refute_includes klass.included_modules, PublicActivity::Creation
    assert_includes klass.included_modules, PublicActivity::Destruction
    assert_includes klass.included_modules, PublicActivity::Update
  end

  def test_tracked_and_activist_at_the_same_time
    a = Class.new(ActiveRecord::Base) do
      self.abstract_class = true
      self.table_name = 'articles'
      include PublicActivity::Model
      tracked
      activist

      belongs_to :user

      def self.name
        "Article"
      end
    end.new
    a.save
    assert_equal a.id, a.activities.last.trackable_id
    assert_equal nil, a.activities.last.owner_id
  end

  def test_tracked_options_only
    options = {:only => [:create, :destroy, :update]}
    klass = article(options)
    assert_includes klass.included_modules, PublicActivity::Common
    assert_includes klass.included_modules, PublicActivity::Creation
    assert_includes klass.included_modules, PublicActivity::Destruction
    assert_includes klass.included_modules, PublicActivity::Update
  end

  def test_reset_instance_options_on_save
    a = article.new
    a.activity :key => 'test'
    a.save
    assert_equal 1, a.activities.count
    assert_raises(PublicActivity::NoKeyProvided) {a.create_activity}
    a.activity :key => 'asd'
    a.create_activity
    assert_raises(PublicActivity::NoKeyProvided) {a.create_activity}
  end

  def test_tracked_options_owner
    options = {:owner => mock('owner')}
    klass = article(options)
    assert_equal(options[:owner], klass.activity_owner_global)
  end

 def test_tracked_options_recipient
    options = {:recipient => mock('recipient')}
    klass = article(options)
    assert_equal(options[:recipient], klass.activity_recipient_global)
  end

  def test_tracked_options_params
    options = {:params => {:a => 1}}
    klass = article(options)
    assert_equal(options[:params], klass.activity_params_global, '#tracked :params option not set')
  end

  def test_tracked_options_on
    options = {:on => {:a => lambda {}}, :b => proc {}}
    klass = article(options)
    assert_equal(options[:on], klass.activity_hooks, '#tracked :on option not set')
  end

  def test_tracked_options_on_symbolize_keys
    options = {:on => {'a' => lambda {}}}
    klass = article(options)
    assert_equal options[:on].symbolize_keys, klass.activity_hooks
  end

  def test_tracked_options_on_proc_values
    options = {:on => {:unpassable => 1, :proper => lambda{}, :proper_proc => proc {}}}
    klass = article(options)
    assert_includes klass.activity_hooks, :proper
    assert_includes klass.activity_hooks, :proper_proc
    refute_includes klass.activity_hooks, :unpassable
  end

  def test_get_hook
    p = lambda {}
    klass = article
    klass.activity_hooks = {:test => p}
    assert_equal p, klass.get_hook(:test)
  end

  def test_get_hook_symbolize_key
    p = lambda {}
    klass = article
    klass.activity_hooks = {:test => p}
    assert_same klass.get_hook('test'), p
  end

  def test_get_hook_on_no_hook_available
    klass = article
    klass.activity_hooks = {}
    assert_same nil, klass.get_hook(:nonexistent)
  end

  def test_refusing_hooks_on_actions
    @article = article.new(:name => 'Some Name')
    PublicActivity.set_controller(10)
    p = proc { |model, controller|
      assert_equal "Some Name", model.name
      assert_equal 10, controller
      false
    }
    @article.class.activity_hooks = {:create => p, :update => p, :destroy => p}

    @article.save
    @article.published = true
    @article.save
    article_id = @article.id
    @article.destroy
    assert_empty @article.activities
  end

  def test_accepting_hooks_on_actions
    @article = article.new(:name => 'Some Name')
    PublicActivity.set_controller(10)
    p = lambda { |model, controller|
      assert_equal "Some Name", model.name
      assert_equal 10, controller
      true
    }
    @article.class.activity_hooks = {:create => p, :update => p, :destroy => p}

    @article.save
    @article.published = true
    @article.save
    article_id = @article.id
    @article.destroy
    refute_empty @article.activities
    assert_equal 3, @article.activities.count
    assert_equal "article.create", @article.activities[0].key
    assert_equal "article.update", @article.activities[1].key
    assert_equal "article.destroy", @article.activities[2].key
  end

  def test_globally_disabling_public_activity
    PublicActivity.enabled = false
    activity_count_before = PublicActivity::Activity.count

    klass = article
    @article = klass.new
    @article.activity :key => 'test'
    @article.save
    assert_equal activity_count_before, PublicActivity::Activity.count

    PublicActivity.enabled = true
  end

  def test_disabling_public_activity_in_a_class
    activity_count_before = PublicActivity::Activity.count

    klass = article
    klass.public_activity_off
    @article = klass.new
    @article.activity :key => 'test'
    @article.save
    assert_equal activity_count_before, PublicActivity::Activity.count

    klass.public_activity_on
  end
end
