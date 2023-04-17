# frozen_string_literal: true

require 'rails_helper'

describe ::Caffeinate::Dripper::Callbacks do
  class CallbacksTestOneDripper < ::Caffeinate::Dripper::Base
    self.campaign = :callbacks_test_one

    on_subscribe do
      @ran = true
    end
  end

  class CallbacksTestTwoDripper < ::Caffeinate::Dripper::Base
    self.campaign = :callbacks_test_two

    on_subscribe do
      @ran = true
    end

    on_subscribe do
      @ran_two = true
    end
  end

  let!(:campaign_one) { create(:caffeinate_campaign, slug: :callbacks_test_one) }
  let(:campaign) { create(:caffeinate_campaign, :with_dripper) }
  let(:dripper) { campaign.to_dripper }
  let(:company) { create(:company) }
  let(:subscription) { campaign.subscribe(company) }
  let(:mailing) { subscription.caffeinate_mailings.first }
  let!(:campaign_two) { create(:caffeinate_campaign, slug: :callbacks_test_two) }

  let(:mailing) { subscription.caffeinate_mailings.first }
  let(:subscription) { campaign.subscribe(company) }
  let(:company) { create(:company) }
  let(:dripper) { campaign.to_dripper }
  let(:campaign) { create(:caffeinate_campaign, :with_dripper) }

  describe '.on_subscribe' do
    it 'works' do
      company = create(:company)
      expect(CallbacksTestOneDripper.on_subscribe_blocks.size).to eq(1)
      expect(CallbacksTestOneDripper.instance_variable_get(:@ran)).to be_falsey
      campaign_one.subscribe(company)
      expect(CallbacksTestOneDripper.instance_variable_get(:@ran)).to be_truthy

      expect(CallbacksTestTwoDripper.on_subscribe_blocks.size).to eq(2)
      expect(CallbacksTestTwoDripper.instance_variable_get(:@ran)).to be_falsey
      expect(CallbacksTestTwoDripper.instance_variable_get(:@ran_two)).to be_falsey
      campaign_two.subscribe(company)
      expect(CallbacksTestTwoDripper.instance_variable_get(:@ran)).to be_truthy
      expect(CallbacksTestTwoDripper.instance_variable_get(:@ran_two)).to be_truthy
    end
  end

  describe '.before_perform' do
    before do
      dripper.cattr_accessor :before_performing
    end

    it 'runs before dripper#process! is called' do
      dripper.before_perform do
        dripper.before_performing = 1
      end
      dripper.perform!
      expect(dripper.before_performing).to eq(1)
    end

    context 'yields' do
      before do
        dripper.before_perform do |*args|
          dripper.before_performing = args
        end
        dripper.perform!
      end

      it 'yields 1 arg' do
        expect(dripper.before_performing.size).to be(1)
      end

      it 'first arg is the dripper' do
        expect(dripper.before_performing[0]).to be_a(dripper)
      end
    end
  end

  describe '.on_process' do
    before do
      dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
      Timecop.travel(1.minute.from_now)
      company = create(:company)
      campaign.subscribe(company)
      dripper.cattr_accessor :on_performing
    end

    it 'runs when dripper#process! is called' do
      dripper.on_perform do
        dripper.on_performing = 1
      end
      expect(dripper.on_performing).to be_nil
      campaign.to_dripper.perform!
      expect(dripper.on_performing).to eq(1)
    end

    it 'yields a Caffeinate::Dripper, Mailing [Array]' do
      dripper.on_perform do |*args|
        dripper.on_performing = args
      end
      dripper.perform!
      args = dripper.on_performing
      expect(args.size).to be(2)
      expect(args[0]).to be_a(Caffeinate::Dripper::Base)
      expect(args[0]).to be_a(dripper)
      expect(args[1]).to be_a(ActiveRecord::Relation)
      expect(args[1].name).to eq('Caffeinate::Mailing')
    end
  end

  describe '.after_perform' do
    before do
      dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
      company = create(:company)
      campaign.subscribe(company)
      dripper.cattr_accessor :after_performing
    end

    it 'runs after dripper#process! is called' do
      dripper.after_perform do
        dripper.after_performing = 1
      end
      expect(dripper.after_perform_blocks.size).to eq(1)
      expect(dripper.after_performing).to be_nil
      campaign.to_dripper.perform!
      expect(dripper.after_performing).to eq(1)
    end

    it 'yields a Caffeinate::Dripper, Mailing [Array]' do
      dripper.after_perform do |*args|
        dripper.after_performing = args
      end
      expect(dripper.after_performing).to be_nil
      campaign.to_dripper.perform!
      expect(dripper.after_performing.size).to eq(1)
      expect(dripper.after_performing.first).to be_a(dripper)
    end
  end

  describe '.before_drip' do
    before do
      dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
      dripper.cattr_accessor :before_dripping
    end

    context 'yields' do
      before do
        dripper.before_drip do |*args|
          dripper.before_dripping = args
        end

        drip = dripper.drip_collection.values.first
        drip.enabled?(Caffeinate::Mailing.new)
      end

      it 'yields two args' do
        expect(dripper.before_dripping.size).to eq(2)
      end

      it 'first arg is the drip' do
        expect(dripper.before_dripping.first).to be_a(::Caffeinate::Drip)
      end

      it 'second arg is the mailing' do
        expect(dripper.before_dripping.second).to be_a(Caffeinate::Mailing)
      end
    end
  end

  describe '.on_resubscribe' do
    before do
      dripper.cattr_accessor :on_resubscribing
    end

    it 'runs before drip has called the mailer' do
      dripper.on_resubscribe do |*args|
        dripper.on_resubscribing = args
      end
      dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
      company = create(:company)
      subscription = campaign.subscribe(company)
      expect(dripper.on_resubscribing).to be_nil
      subscription.resubscribe!
      expect(dripper.on_resubscribing.size).to eq(1)
      expect(dripper.on_resubscribing.first).to be_a(::Caffeinate::CampaignSubscription)
    end
  end

  describe '.before_send' do
    before do
      dripper.cattr_accessor :before_sending
    end

    let(:mail) { Mail.from_source("Date: Fri, 28 Sep 2018 11:08:55 -0700\r\nTo: a@example.com\r\nMime-Version: 1.0\r\nContent-Type: text/plain\r\nContent-Transfer-Encoding: 7bit\r\n\r\nHello!") }

    it 'does not run if caffeinate_mailing is false' do
      dripper.before_send do
        dripper.before_sending = 1
      end
      ::Caffeinate::ActionMailer::Interceptor.delivering_email(mail)
      expect(dripper.before_sending).not_to eq(1)
    end

    it 'runs if caffeinate_mailing is present' do
      dripper.before_send do
        dripper.before_sending = 1
      end
      dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
      company = create(:company)
      subscription = campaign.subscribe(company)
      mail.caffeinate_mailing = subscription.caffeinate_mailings.first
      ::Caffeinate::ActionMailer::Interceptor.delivering_email(mail)
      expect(dripper.before_sending).to eq(1)
    end

    context 'yields' do
      before do
        dripper.before_send do |*args|
          dripper.before_sending = args
        end
        dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
        company = create(:company)
        subscription = campaign.subscribe(company)
        mail.caffeinate_mailing = subscription.caffeinate_mailings.first
        ::Caffeinate::ActionMailer::Interceptor.delivering_email(mail)
      end

      it 'yields two args' do
        expect(dripper.before_sending.size).to eq(2)
      end

      it 'first arg is the caffeinate mailing' do
        expect(dripper.before_sending[0]).to eq(mail.caffeinate_mailing)
      end

      it 'second arg is the mail' do
        expect(dripper.before_sending[1]).to eq(mail)
      end
    end
  end

  describe '.after_send' do
    before do
      dripper.cattr_accessor :after_sending
    end

    let(:mail) { Mail.from_source("Date: Fri, 28 Sep 2018 11:08:55 -0700\r\nTo: a@example.com\r\nMime-Version: 1.0\r\nContent-Type: text/plain\r\nContent-Transfer-Encoding: 7bit\r\n\r\nHello!") }

    context 'if caffeinate_mailing is false' do
      before do
        dripper.after_send do
          dripper.after_sending = 1
        end
      end

      it 'does not run' do
        ::Caffeinate::ActionMailer::Observer.delivered_email(mail)
        expect(dripper.after_sending).to_not eq(1)
      end
    end

    context 'if caffeinate_mailing is present' do
      before do
        dripper.after_send do
          dripper.after_sending = 1
        end
        dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
        company = create(:company)
        subscription = campaign.subscribe(company)
        mail.caffeinate_mailing = subscription.caffeinate_mailings.first
      end

      it 'runs' do
        ::Caffeinate::ActionMailer::Observer.delivered_email(mail)
        expect(dripper.after_sending).to eq(1)
      end
    end

    context 'yields' do
      before do
        dripper.after_send do |*args|
          dripper.after_sending = args
        end
        dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
        company = create(:company)
        subscription = campaign.subscribe(company)
        mail.caffeinate_mailing = subscription.caffeinate_mailings.first
        ::Caffeinate::ActionMailer::Observer.delivered_email(mail)
      end

      it 'yields two args' do
        expect(dripper.after_sending.size).to eq(2)
      end

      it 'first arg is the caffeinate_mailing' do
        expect(dripper.after_sending[0]).to eq(mail.caffeinate_mailing)
      end

      it 'second arg is the Mail::Message' do
        expect(dripper.after_sending[1]).to eq(mail)
      end
    end
  end

  describe '.on_end' do
    before do
      dripper.cattr_accessor :on_ending
    end

    context 'Caffeinate::CampaignSubscription#end!' do
      before do
        dripper.on_end do
          dripper.on_ending = 1
        end
      end

      it 'is nil if #end! has not been called' do
        expect(dripper.on_ending).to be_nil
      end

      context 'after #end! has been called' do
        it 'is 1' do
          subscription.end!
          expect(dripper.on_ending).to be(1)
        end
      end
    end


    it 'yields a CampaignSubscriber' do
      dripper.on_end do |*args|
        dripper.on_ending = args
      end
      subscription.end!
      expect(dripper.on_ending.first).to eq(subscription)
    end
  end

  describe '.on_unsubscribe' do
    before do
      dripper.cattr_accessor :on_unsubscribing
    end

    context 'Mailing#unsibscribe' do
      before do
        dripper.on_unsubscribe do
          dripper.on_unsubscribing = 1
        end
      end

      it 'has not run until #unsubscribe! has been called' do
        expect(dripper.on_unsubscribing).to be_nil
      end

      context '#unsubscribe!' do
        it 'runs' do
          subscription.unsubscribe!
          expect(dripper.on_unsubscribing).to be(1)
        end
      end
    end

    context 'yields' do
      before do
        dripper.on_unsubscribe do |*args|
          dripper.on_unsubscribing = args
        end

        subscription.unsubscribe!
      end

      it 'yields 1 arg' do
        expect(dripper.on_unsubscribing.size).to be(1)
      end

      it 'yields a CampaignSubscriber' do
        expect(dripper.on_unsubscribing.first).to be(subscription)
      end
    end
  end

  describe '.on_skip' do
    before do
      dripper.cattr_accessor :on_skipping
      dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
      company = create(:company)
      campaign.subscribe(company)
    end

    it 'runs after before Mailing#skip! has been called' do
      dripper.on_skip do
        dripper.on_skipping = 1
      end
      expect(dripper.on_skipping).to be_nil
      mailing.skip!
      expect(dripper.on_skipping).to be(1)
    end

    context 'yields' do
      before do
        dripper.on_skip do |*args|
          dripper.on_skipping = args
        end
        mailing.skip!

      end
      it 'yields one arg' do
        expect(dripper.on_skipping.size).to be(1)
      end

      it 'yields the mailing' do
        expect(dripper.on_skipping.first).to be(mailing)
      end
    end
  end
end
