# frozen_string_literal: true

require 'rails_helper'

describe ::Caffeinate::DeliverAsync do
  class DeliverAsyncTest
    include Caffeinate::DeliverAsync
  end

  let!(:campaign) { create(:caffeinate_campaign, :with_dripper) }
  let(:subscription) { create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign) }

  describe '#perform' do
    it 'delivers a pending mail' do
      campaign.to_dripper.drip :hello, mailer_class: 'ArgumentMailer', delay: 0.hours
      Timecop.travel(1.minute.from_now)

      expect(subscription.caffeinate_mailings.count).to eq(1)
      mailing = subscription.next_caffeinate_mailing
      expect(mailing).to be_pending

      DeliverAsyncTest.new.perform(mailing.id)
      mailing.reload
      expect(mailing).not_to be_pending
    end
  end
end
