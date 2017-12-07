require_relative 'hawkular_helper'
# VCR Cassettes: Hawkular Services 0.40.0.Final-SNAPSHOT (commit 61ad2c1db6dc94062841ca2f5be9699e69d96cfe)

describe ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareMessaging do
  vcr_cassete_name = described_class.name.underscore.to_s

  let(:ems_hawkular) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    auth = AuthToken.new(:name     => "test",
                         :auth_key => "valid-token",
                         :userid   => test_userid,
                         :password => test_password)
    FactoryGirl.create(:ems_hawkular,
                       :hostname        => test_hostname,
                       :port            => test_port,
                       :authentications => [auth],
                       :zone            => zone)
  end

  let(:eap) do
    FactoryGirl.create(:hawkular_middleware_server,
                       :id                    => 1,
                       :name                  => 'Local',
                       :feed                  => test_mw_manager_feed_id,
                       :ems_ref               => "#{test_mw_manager_feed_id}~Local~~",
                       :nativeid              => "#{test_mw_manager_feed_id}~Local~~",
                       :ext_management_system => ems_hawkular)
  end

  ['JMS Queue WF10', 'JMS Topic WF10'].each do |ms_model|
    describe ms_model do
      let(:ms) do
        if ms_model == 'JMS Queue WF10'
          FactoryGirl.create(:hawkular_middleware_messaging_initialized_queue,
                             :ems_ref               => "#{test_mw_manager_feed_id}~Local~/subsystem=messaging-activemq/server=default/jms-queue=DLQ",
                             :ext_management_system => ems_hawkular,
                             :middleware_server     => eap,
                             :messaging_type        => ms_model)
        else
          FactoryGirl.create(:hawkular_middleware_messaging_initialized_topic,
                             :ems_ref               => "#{test_mw_manager_feed_id}~Local~/subsystem=messaging-activemq/server=default/jms-topic=HawkularCommandEvent",
                             :ext_management_system => ems_hawkular,
                             :middleware_server     => eap,
                             :messaging_type        => ms_model)
        end
      end

      let(:expected_metrics) do
        if ms_model == 'JMS Queue WF10'
          {
            "Consumer Count"   => "mw_ms_queue_consumer_count",
            "Delivering Count" => "mw_ms_queue_delivering_count",
            "Message Count"    => "mw_ms_queue_message_count",
            "Messages Added"   => "mw_ms_queue_messages_added",
            "Scheduled Count"  => "mw_ms_queue_scheduled_count"
          }.freeze
        else
          {
            "Delivering Count"               => "mw_ms_topic_delivering_count",
            "Durable Message Count"          => "mw_ms_topic_durable_message_count",
            "Durable Subscription Count"     => "mw_ms_topic_durable_subscription_count",
            "Message Count"                  => "mw_ms_topic_message_count",
            "Messages Added"                 => "mw_ms_topic_message_added",
            "Non-Durable Message Count"      => "mw_ms_topic_non_durable_message_count",
            "Non-Durable Subscription Count" => "mw_ms_topic_non_durable_subscription_count",
            "Subscription Count"             => "mw_ms_topic_subscription_count"
          }.freeze
        end
      end

      it "#collect_stats_metrics for #{ms_model}" do
        start_time = test_start_time
        end_time = test_end_time
        interval = 3600
        VCR.use_cassette(vcr_cassete_name,
                         :allow_unused_http_interactions => true,
                         :match_requests_on              => [:method, :uri, :body],
                         :decode_compressed_response     => true) do # , :record => :new_episodes) do
          metrics_available = ms.metrics_available
          metrics_ids_map, raw_stats = ms.collect_stats_metrics(metrics_available, start_time, end_time, interval)
          expect(metrics_ids_map.keys.size).to be > 0
          expect(raw_stats.keys.size).to be > 0
        end
      end

      it "#collect_live_metrics for all metrics available for #{ms_model}" do
        start_time = test_start_time
        end_time = test_end_time
        interval = 3600
        VCR.use_cassette(vcr_cassete_name,
                         :allow_unused_http_interactions => true,
                         :match_requests_on              => [:method, :uri, :body],
                         :decode_compressed_response     => true) do # , :record => :new_episodes) do
          metrics_available = ms.metrics_available
          metrics_data = ms.collect_live_metrics(metrics_available, start_time, end_time, interval)
          keys = metrics_data.keys
          expect(metrics_data[keys[0]].keys.size).to be > 3
        end
      end

      it "#collect_live_metrics for three metrics for #{ms_model}" do
        start_time = test_start_time
        end_time = test_end_time
        interval = 3600
        VCR.use_cassette(vcr_cassete_name,
                         :allow_unused_http_interactions => true,
                         :match_requests_on              => [:method, :uri, :body],
                         :decode_compressed_response     => true) do # , :record => :new_episodes) do
          metrics_available = ms.metrics_available
          expect(metrics_available.size).to be > 3
          metrics_data = ms.collect_live_metrics(metrics_available[0, 3],
                                                 start_time,
                                                 end_time,
                                                 interval)
          keys = metrics_data.keys
          # Assuming that for the test the first key has data for 3 metrics
          expect(metrics_data[keys[0]].keys.size).to eq(3)
        end
      end

      it "#first_and_last_capture for #{ms_model}" do
        VCR.use_cassette(vcr_cassete_name,
                         :allow_unused_http_interactions => true,
                         :match_requests_on              => [:method, VCR.request_matchers.uri_without_params(:end, :start)],
                         :decode_compressed_response     => true) do # , :record => :new_episodes) do
          capture = ms.first_and_last_capture
          expect(capture.any?).to be true
          expect(capture[0]).to be < capture[1]
        end
      end

      it "#supported_metrics for #{ms_model}" do
        supported_metrics = ms.supported_metrics[ms_model]
        expected_metrics.each { |k, v| expect(supported_metrics[k]).to eq(v) }

        model_config = MiddlewareMessaging.live_metrics_config
        supported_metrics = model_config['supported_metrics'][ms_model]
        expected_metrics.each { |k, v| expect(supported_metrics[k]).to eq(v) }
      end
    end
  end
end
