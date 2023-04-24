# frozen_string_literal: true

# == Schema Information
#
# Table name: caffeinate_mailings
#
#  id                                  :integer          not null, primary key
#  caffeinate_campaign_subscription_id :integer          not null
#  send_at                             :datetime
#  sent_at                             :datetime
#  skipped_at                          :datetime
#  mailer_class                        :string           not null
#  mailer_action                       :string           not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#
require 'rails_helper'

describe ::Caffeinate::Mailing do
  let!(:campaign) { create(:caffeinate_campaign, :with_dripper, slug: :caffeinate_active_record_extension) }
  let(:subscription) { create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign) }
  let!(:unsent_mailings) { create_list(:caffeinate_mailing, 5, :unsent, caffeinate_campaign_subscription: subscription) }
  let!(:sent_mailings) { create_list(:caffeinate_mailing, 3, :sent, caffeinate_campaign_subscription: subscription) }
  let!(:skipped_mailings) { create_list(:caffeinate_mailing, 2, :skipped, caffeinate_campaign_subscription: subscription) }

  describe '#unsent' do
    it 'has 5 unsent mailings' do
      expect(described_class.unsent.count).to eq(5)
      expect(described_class.unsent).to eq(unsent_mailings)
    end
  end

  describe '#sent' do
    it 'has 3 sent mailings' do
      expect(described_class.sent.count).to eq(3)
      expect(described_class.sent).to eq(sent_mailings)
    end
  end

  describe '#skipped' do
    it 'has 3 skipped mailings' do
      expect(described_class.skipped.count).to eq(2)
      expect(described_class.skipped).to eq(skipped_mailings)
      expect(described_class.unskipped.count).to eq(8)
    end
  end

  describe '#process' do
    context 'async' do
      it 'enqueues a job' do
        class MyJob < ActiveJob::Base
          include ::Caffeinate::DeliverAsync
        end
        Caffeinate.config.async_delivery_class = 'MyJob'
        Caffeinate.config.async_delivery = true
        mailing = sent_mailings.first.dup
        mailing.mailer_action = 'test'
        mailing.mailer_class = 'SuperTestMailer'
        mailing.caffeinate_campaign_subscription = create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign)
        expect do
          mailing.process!
        end.to change {
          ActiveJob::Base.queue_adapter.enqueued_jobs.count
        }.by 1
        Caffeinate.config.async_delivery_class = nil
        Caffeinate.config.async_delivery = false
      end
    end
  end

  describe '#pending?' do
    [[:sent_at], [:skipped_at], [:sent_at, :skipped_at]].each do |attributes|
      [Time.current, 50.years.from_now, 50.years.ago].each do |time|
        it "is not sent or skipped if #{attributes.join(", ")} if time is #{time}" do
          mailing = Caffeinate::Mailing.new
          attributes.each do |attr|
            mailing.write_attribute(attr, time)
          end
          expect(mailing).not_to be_pending
        end
      end
    end
  end

  context 'skipped' do
    describe '#skipped?' do
      it 'has a present skipped_at' do
        mailing = described_class.new
        expect(mailing).not_to be_skipped
        mailing.skipped_at = Time.current
        expect(mailing).to be_skipped
        mailing.skipped_at = 50.years.ago
        expect(mailing).to be_skipped
        mailing.skipped_at = 50.years.from_now
        expect(mailing).to be_skipped
        mailing.skipped_at = nil
        expect(mailing).not_to be_skipped
      end
    end

    describe '#process!' do
      let!(:mailing_campaign) { create(:caffeinate_campaign, :with_dripper, slug: :skipped_mailing) }
      before do
        mailing_campaign.to_dripper.drip :happy, mailer_class: 'SkippedMailingMailer', delay: 0.hours, using: :parameterized
      end
      let!(:skipped_subscription) { create(:caffeinate_campaign_subscription, caffeinate_campaign: mailing_campaign) }

      class SkippedMailingMailer < ActionMailer::Base
        def happy
          mail(to: 'hello@example.com', from: 'hello@example.com', subject: 'hello') do |format|
            format.text { render plain: 'hi' }
          end
        end
      end

      it 'sets skipped to nil' do
        mailing = skipped_subscription.caffeinate_mailings.first
        mailing.skip!
        expect(mailing).to be_skipped
        mailing.process!
        expect(mailing).not_to be_skipped
        expect(mailing).to be_sent
      end
    end
  end

  context 'delegated methods' do
    let(:mailing) { unsent_mailings.first }

    describe '#user' do
      it 'delegates to caffeinate_campaign_subscription' do
        expect(mailing.user).to eq(mailing.caffeinate_campaign_subscription.user)
      end
    end

    describe '#subscriber' do
      it 'delegates to caffeinate_campaign_subscription' do
        expect(mailing.subscriber).to eq(mailing.caffeinate_campaign_subscription.subscriber)
      end
    end
  end

  context 'scopes' do
    describe '.upcoming' do
      it 'is only active subscriptions' do
        Timecop.freeze do
          sql = ::Caffeinate::Mailing.upcoming.to_sql
          expect(sql).to include(Caffeinate::CampaignSubscription.active.select(:id).to_sql)
        end
      end
    end
  end

  describe '#deliver_later!' do
    class FakeAsyncDeliveryLater
      def self.perform_later(id)

      end
    end
    class FakeAsyncDeliveryAsync
      def self.perform_async(id)

      end
    end

    context 'async' do
      before do
        ::Caffeinate.config.async_delivery_class = 'FakeAsyncDeliveryAsync'
      end

      after do
        ::Caffeinate.config.async_delivery_class = nil
      end
      let(:mailing) { unsent_mailings.first }

      it 'calls the later' do
        expect(FakeAsyncDeliveryAsync).to receive(:perform_async).with(mailing.id)
        mailing.deliver_later!
      end
    end

    context 'later' do
      before do
        ::Caffeinate.config.async_delivery_class = 'FakeAsyncDeliveryLater'
      end

      after do
        ::Caffeinate.config.async_delivery_class = nil
      end
      let(:mailing) { unsent_mailings.first }

      it 'calls the later' do
        expect(FakeAsyncDeliveryLater).to receive(:perform_later).with(mailing.id)
        mailing.deliver_later!
      end
    end
  end

  context '#end_if_no_mailings' do
    let(:subscription) { create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign) }
    let(:unsent) { create_list(:caffeinate_mailing, 5, :unsent, caffeinate_campaign_subscription: subscription) }

    it 'ends!' do
      subscription.future_mailings.update_all(sent_at: Time.current)
      expect_any_instance_of(Caffeinate::CampaignSubscription).to receive(:end!)
      subscription.mailings.last.touch
    end
  end
end
