# frozen_string_literal: true

require 'rails_helper'

describe Caffeinate::CampaignSubscriptionsController, type: :controller do
  render_views
  routes { Caffeinate::Engine.routes }
  let!(:campaign) { create(:caffeinate_campaign, :with_dripper, slug: 'campaign_subscriptions_controller_test') }

  context 'a valid token' do
    it 'subscribes if subscribed' do
      subscription = create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign)
      expect(subscription).to be_subscribed
      get :subscribe, params: { token: subscription.token }
      expect(response.body).to include('subscribed')
      expect(response).to have_http_status(:ok)
      subscription.reload
      expect(subscription).to be_subscribed
      expect(subscription).not_to be_unsubscribed
    end
  end

  context 'a valid token' do
    it 'unsubscribes if not subscribed' do
      subscription = create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign)
      expect(subscription).to be_subscribed
      get :unsubscribe, params: { token: subscription.token }
      expect(response.body).to include('unsubscribed')
      expect(response).to have_http_status(:ok)
      subscription.reload
      expect(subscription).not_to be_subscribed
      expect(subscription).to be_unsubscribed
    end

    it 'unsubscribes even if already unsubscribed' do
      subscription = create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign, unsubscribed_at: Time.current)
      expect(subscription).not_to be_subscribed
      get :unsubscribe, params: { token: subscription.token }
      expect(response.body).to include('unsubscribed')
      expect(response).to have_http_status(:ok)
      subscription.reload
      expect(subscription).not_to be_subscribed
      expect(subscription).to be_unsubscribed
    end
  end

  context 'an invalid token' do
    it 'raises ActiveRecord::RecordNotFound' do
      expect do
        get :unsubscribe, params: { token: 'meow' }
      end.to raise_error(::ActiveRecord::RecordNotFound)
    end
  end

  context 'helpers' do
    describe '#caffeinate_unsubscribe_url' do
      it 'is the proper url' do
        subscription = create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign)
        klass = described_class.new
        klass.instance_variable_set(:@campaign_subscription, subscription)
        expect(klass.send(:caffeinate_unsubscribe_url)).to eq("http://caffeinate.test/caffeinate/campaign_subscriptions/#{subscription.token}/unsubscribe")
      end
    end

    describe '#caffeinate_subscribe_url' do
      it 'is the proper url' do
        subscription = create(:caffeinate_campaign_subscription, caffeinate_campaign: campaign)
        klass = described_class.new
        klass.instance_variable_set(:@campaign_subscription, subscription)
        expect(klass.send(:caffeinate_subscribe_url)).to eq("http://caffeinate.test/caffeinate/campaign_subscriptions/#{subscription.token}/subscribe")
      end
    end
  end
end
