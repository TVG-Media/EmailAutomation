# frozen_string_literal: true

require 'rails_helper'

describe ::Caffeinate::Dripper::Delivery do
  class DeliveryTestMailer < ActionMailer::Base
    before_action do
      @thing = '123'
    end

    def welcome(_)
      mail(to: 'hello@example.com', from: 'bob@example.com', subject: 'sup') do |format|
        format.text { render plain: 'Hi' }
      end
    end

    def with_params
      mail(to: 'hello@example.com', from: 'hello@examle.com', subject: @thing) do |format|
        format.text { render plain: 'hi' }
      end
    end

    def goodbye(_)
      mail(to: 'hello@example.com', from: 'bob@example.com', subject: 'sup') do |format|
        format.text { render plain: 'Hi' }
      end
    end
    alias goodbye_end goodbye
    alias goodbye_unsubscribe goodbye
  end

  class DeliveryTestDripper < ::Caffeinate::Dripper::Base
    self.campaign = :delivery_test_dripper

    rescue_from StandardError do
      end!
    end

    default mailer_class: 'DeliveryTestMailer'

    drip :welcome, delay: 0.hours
    drip :with_params, delay: 0.hours, using: :parameterized
    drip :goodbye, delay: 0.hours do
      false
    end

    drip :goodbye_end, delay: 0.hours do
      end!
    end

    drip :goodbye_unsubscribe, delay: 0.hours do; end
  end

  let(:campaign) { create(:caffeinate_campaign, slug: 'delivery_test_dripper') }
  let(:campaign_subscription) { create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign) }
  let(:mailing) { create(:caffeinate_mailing, caffeinate_campaign_subscription: campaign_subscription, mailer_class: 'DeliveryTestMailer', mailer_action: 'welcome') }

  describe '.deliver!' do
    it 'is not already sent' do
      expect(mailing.sent_at).to be_nil
    end
    it 'sends it' do
      expect do
        DeliveryTestDripper.deliver!(mailing)
      end.to change(::ActionMailer::Base.deliveries, :size).by(1)
      expect(mailing.sent_at).to be_present
    end
  end

  describe '.deliver! with parameterized' do
    let(:mailing) { create(:caffeinate_mailing, caffeinate_campaign_subscription: campaign_subscription, mailer_class: 'DeliveryTestMailer', mailer_action: 'with_params') }

    it 'using parameterized' do
      expect(mailing.sent_at).to be_nil
      expect do
        DeliveryTestDripper.deliver!(mailing)
      end.to change(::ActionMailer::Base.deliveries, :size).by(1)
      expect(mailing.sent_at).to be_present
      expect(::ActionMailer::Base.deliveries.last.subject).to eq('123')
    end
  end

  shared_examples_for 'block that returns false' do
    it 'does not send' do
      expect(mailing.sent_at).to be_nil
      expect do
        do_action
      end.not_to change(::ActionMailer::Base.deliveries, :size)
      expect(mailing.sent_at).to be_nil
      mailing.caffeinate_campaign_subscription.reload
    end
  end

  shared_examples_for 'block that returns false and unsubscribes' do
    it 'does not send' do
      expect(mailing.sent_at).to be_nil
      expect do
        do_action
      end.not_to change(::ActionMailer::Base.deliveries, :size)
      expect(mailing.sent_at).to be_nil
      mailing.caffeinate_campaign_subscription.reload
    end
  end

  context 'with a block that returns false' do
    let(:mailing) { create(:caffeinate_mailing, caffeinate_campaign_subscription: campaign_subscription, mailer_class: 'DeliveryTestMailer', mailer_action: 'goodbye') }
    let(:do_action) { DeliveryTestDripper.deliver!(mailing) }

    it_behaves_like 'block that returns false'
  end

  context 'with a block that returns false' do
    let(:mailing) { create(:caffeinate_mailing, caffeinate_campaign_subscription: campaign_subscription, mailer_class: 'DeliveryTestMailer', mailer_action: 'goodbye_end') }
    let(:do_action) { DeliveryTestDripper.deliver!(mailing) }

    it_behaves_like 'block that returns false and unsubscribes'
  end

  context 'error' do
    before do
      DeliveryTestDripper.rescue_from StandardError do |exception|
        self.caffeinate_campaign_subscription.end
      end

      allow_any_instance_of(::Mail::Message).to receive(:deliver).and_raise(StandardError)
    end

    let(:mailing) { create(:caffeinate_mailing, caffeinate_campaign_subscription: campaign_subscription, mailer_class: 'DeliveryTestMailer', mailer_action: 'goodbye_end') }
    let(:do_action) { DeliveryTestDripper.deliver!(mailing) }

    it 'is handled gracefully' do
      expect { do_action }.to_not raise_error(StandardError)
    end

    it 'unsubscribes' do
      expect { do_action }.to change(mailing.caffeinate_campaign_subscription, :ended_at)
    end
  end
end
