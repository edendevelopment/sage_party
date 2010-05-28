require 'digest'
require 'active_support'
require 'party_resource'

PartyResource::Connector.add(:sage_party, {})

module SageParty
  class Transaction
    include PartyResource

    party_connector :sage_party
    URLS = {:simulator => 'https://test.sagepay.com/simulator/VSPServerGateway.asp?Service=VendorRegisterTx',
            :test => 'https://test.sagepay.com/gateway/service/vspserver-register.vsp',
            :live => 'https://live.sagepay.com/gateway/service/vspserver-register.vsp'}
    ::SAGE_PAY_SERVER = :simulator unless Object.const_defined?('SAGE_PAY_SERVER')

    connect :raw_register, :post => URLS[::SAGE_PAY_SERVER.to_sym], :as => :raw

    %w{VPSProtocol StatusDetail VPSTxId SecurityKey NextURL
      VPSTxId VendorTxCode Status TxAuthNo VendorName AVSCV2 SecurityKey
      AddressResult PostCodeResult CV2Result GiftAid CAVV AddressStatus
      PayerStatus CardType Last4Digits VPSSignature}.each do |name|
      property name.underscore, :from => name
    end
    property :three_d_secure_status, :from => '3DSecureStatus'
    property :id, :vendor_name


    class << self
      # Register a new transaction with SagePay
      # @return [Transaction]
      def register_tx(data)
        response = raw_register(data)
        hash = {}
        response.split("\r\n").each do |line|
          line = line.split("=", 2)
          hash[line.first] = line.last
        end
        self.new(hash.merge({:id => data[:VendorTxCode], :vendor_name => data[:Vendor]}))
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
