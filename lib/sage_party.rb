require 'digest'
require 'active_support'
require 'party_resource'

module SageParty

  URLS = {:simulator => 'https://test.sagepay.com/simulator',
          :test => 'https://test.sagepay.com/gateway/service',
          :live => 'https://live.sagepay.com/gateway/service'}

  ACTIONS = {
    :register => {
      :live => '/vspserver-register.vsp',
      :test => '/vspserver-register.vsp',
      :simulator => '/VSPServerGateway.asp?Service=VendorRegisterTx' },
    :authorise => {
      :live => '/vspserver-authorise.vsp',
      :test => '/vspserver-authorise.vsp',
      :simulator => '/VSPServerGateway.asp?Service=VendorAuthoriseTx' }
  }

  class Transaction
    include PartyResource

    party_connector :sage_party

    %w{VPSProtocol StatusDetail VPSTxId SecurityKey NextURL
      VPSTxId VendorTxCode Status TxAuthNo VendorName AVSCV2 SecurityKey
      AddressResult PostCodeResult CV2Result GiftAid CAVV AddressStatus
      PayerStatus CardType Last4Digits VPSSignature}.each do |name|
      property name.underscore, :from => name
    end
    property :three_d_secure_status, :from => '3DSecureStatus'
    property :id, :vendor_name


    class << self
      # Define which Sage server to use
      # @param [Symbol] server One of :live, :test, or :simulator
      def sage_pay_server(server)
        PartyResource::Connector.add(:sage_party, {:base_uri => SageParty::URLS[server.to_sym]})
        connect :raw_register, :post => action_path(:register, server), :as => :raw
        connect :raw_authorise, :post => action_path(:authorise, server), :as => :raw
      end

      # Register a new transaction with SagePay
      # @return [Transaction]
      def register_tx(data)
        transaction(:raw_register, data)
      end

      def authorise_tx(data)
        transaction(:raw_authorise, data)
      end

      # Find a stored transaction
      # @return [Transaction]
      def find(vendor_id, sage_id)
        transaction = get(vendor_id)
        return missing_transaction if transaction.nil? || transaction.vps_tx_id != sage_id
        transaction
      end

      protected
      def get(vendor_id)
        raise 'self.get method get needs to be defined'
      end

      private
      def missing_transaction
        self.new(:not_found => true)
      end

      def action_path(action, server)
        SageParty::ACTIONS[action][server.to_sym]
      end

      def parse_response(response, data)
        hash = {}
        response.split("\r\n").each do |line|
          line = line.split("=", 2)
          hash[line.first] = line.last
        end
        return hash
      end

      def transaction(action, data)
        response = send(action, data)
        parsed_response = parse_response(response, data)
        self.new(parsed_response.merge({:id => data[:VendorTxCode], :vendor_name => data[:Vendor]}))
      end
    end

    # Return HTTP response to return to SagePay server
    # @return [String]
    def response
      return format_response(:invalid, 'Transaction not found') unless exists?
      return format_response(:invalid, 'Security check failed') unless signature_ok?
      return format_response(:error, 'Sage Pay reported an error') if status == 'ERROR'
      return format_response(:invalid, 'Unexpected status') if %w{AUTHENTICATED REGISTERED}.include?(status)
      return format_response(:invalid, "Invalid status: #{status}") unless %w{OK NOTAUTHED ABORT REJECTED}.include?(status)
      format_response(:ok)
    end

    # Test transaction equality
    # @return [Boolean]
    def ==(other)
      properties_equal?(other) && self.exists? == other.exists?
    end

    # Detrmine if this transaction exists
    def exists?
      !@not_found
    end

    # Merge in transaction stage two data
    # @return [Transaction] self
    def merge!(data)
      data = data.with_indifferent_access
      data.delete(:SecurityKey)
      populate_properties(data)
      self
    end

    # Check if transaction data matches its signature
    def signature_ok?
      generate_md5 == vps_signature
    end

    protected
    def initialize(params)
      populate_properties(params)
      @not_found = params[:not_found]
    end

    def notification_url
      raise 'notification_url method needs to be defined'
    end

    private
    def generate_md5
      Digest::MD5.hexdigest("#{vps_tx_id}#{vendor_tx_code}#{status}#{tx_auth_no}#{vendor_name}#{avscv2}#{security_key}#{address_result}#{post_code_result}#{cv2_result}#{gift_aid}#{three_d_secure_status}#{cavv}#{address_status}#{payer_status}#{card_type}#{last4_digits}").upcase
    end

    def format_response(status, details=nil)
      str = "Status=#{status.to_s.upcase}\r\nRedirectURL=#{notification_url}"
      str += "\r\nStatusDetail=#{details}" unless details.nil?
      str
    end

  end
end
