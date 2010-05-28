require File.dirname(__FILE__) + '/spec_helper'

def m(name)
  v = mock(name)
  instance_variable_set("@#{name}", v)
end

describe SageTransaction do
  describe 'registering a transaction' do
    before do
      SageTransaction.stub!(:raw_register => '')
      SageTransaction.stub!(:tx_id => 'my_tx_id')
      @basket = mock(:basket, :id => mock, :null_object => true)
      @customer = mock(:customer, :null_object => true)
      @data = {:VendorTxCode => m(:tx_code), :Vendor => m(:vendor)}
    end

    it 'registers with the data' do
      SageTransaction.should_receive(:raw_register).with(@data)
      SageTransaction.register_tx(@data)
    end

    it 'parses the response' do
      SageTransaction.stub!(:raw_register => "VPSProtocol=2.23\r\nStatus=OK\r\nStatusDetail=Server transaction registered successfully.\r\nVPSTxId={F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}\r\nSecurityKey=YK4N4LO9PT\r\nNextURL=https://test.sagepay.com/Simulator/VSPServerPaymentPage.asp?SageTransactionID={F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}")
      result = SageTransaction.new({:vps_protocol => '2.23', :status => 'OK', :status_detail => 'Server transaction registered successfully.', :vps_tx_id => '{F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}', :security_key => 'YK4N4LO9PT', :next_url => 'https://test.sagepay.com/Simulator/VSPServerPaymentPage.asp?SageTransactionID={F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}', :id => @tx_code, :vendor_name => @vendor, :basket_id => @basket.id})
      SageTransaction.register_tx(@data).should == result
    end
  end

  describe 'find' do
    it 'looks for the transaction' do
      SageTransaction.should_receive(:get).with('foo')
      SageTransaction.find('foo', 'bar')
    end

    context 'transaction can be found' do
      it 'returns the transaction' do
        transaction = mock(:transaction, :vps_tx_id => 'bar')
        SageTransaction.stub!(:get => transaction)
        SageTransaction.find('foo', 'bar').should == transaction
      end
    end

    context 'transaction cannot be found' do
      it 'returns a "null" transaction' do
        SageTransaction.stub!(:get => nil)
        SageTransaction.find('foo', 'bar').should_not be_exists
      end
    end

    context 'transaction VPSTxId mismatch' do
      it 'returns a "null" transaction' do
        SageTransaction.stub!(:get => mock(:transaction, :vps_tx_id => mock))
        SageTransaction.find('foo', 'bar').should_not be_exists
      end
    end
  end

  describe 'merge!' do
    before do
      @transaction = SageTransaction.new('CardType' => m(:original_card_type), 'Status' => m(:status), 'SecurityKey' => m(:original_security_key))
      @transaction.merge!('GiftAid' => m(:gift_aid), 'CardType' => m(:card_type), 'SecurityKey' => m(:security_key))
    end
      
    it 'repopulates existing data' do
      @transaction.card_type.should == @card_type
    end

    it 'populates new data' do
      @transaction.gift_aid.should == @gift_aid
    end

    it 'leaves unchanged data unchaged' do
      @transaction.status.should == @status
    end

    it 'DOES NOT repopulate the security key' do
      @transaction.security_key.should == @original_security_key
    end
  end 

  describe 'response' do
    before do
      @transaction = SageTransaction.new({:id => mock(:id)})
      @transaction.stub!(:notification_url => 'notify_url')
      @transaction.stub!(:signature_ok? => true)
    end

    def set_status(status)
      @transaction.merge!('Status' => status)
    end 

    def check_response(*args)
      @transaction.response.should == @transaction.format_response(*args)
    end

    context 'transaction not found' do
      it 'returns invalid' do
        @transaction.stub!(:exists? => false)
        check_response(:invalid, 'Transaction not found')
      end
    end

    context 'with incorrect signature' do
      before do
        @transaction.stub!(:signature_ok? => false)
      end

      it 'returns invalid' do
        check_response(:invalid, 'Security check failed')
      end
    end

    context 'when status == ERROR' do
      before do
        set_status('ERROR')
      end

      it 'returns error' do
        check_response(:error, 'Sage Pay reported an error')
      end
    end

    context 'status is an unexpected value' do
      it 'returns invalid when status is incorrect value' do
        set_status('CUSTARD')
        check_response(:invalid, 'Invalid status: CUSTARD')
      end

      it 'returns invalid when status is blank' do
        set_status('')
        check_response(:invalid, 'Invalid status: ')
      end

      it 'returns invalid when status is nil' do
        set_status(nil)
        check_response(:invalid, 'Invalid status: ')
      end

      it 'returns invalid/unexpected when status is AUTHENTICATED' do
        set_status('AUTHENTICATED')
        check_response(:invalid, 'Unexpected status')
      end

      it 'returns invalid/unexpected when status is REGISTERED' do
        set_status('REGISTERED')
        check_response(:invalid, 'Unexpected status')
      end
    end

    context 'status is an expected value' do
      %w{OK NOTAUTHED ABORT REJECTED}.each do |status|
        it "returns ok when status is #{status}" do
          set_status(status)
          check_response(:ok)
        end
      end
    end
  end

  describe 'signature_ok?' do
    before do
      @transaction = SageTransaction.new({:vps_protocol => '2.23', :status => 'OK', :status_detail => 'Server transaction registered successfully.', :vps_tx_id => '{F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}', :security_key => 'YK4N4LO9PT', :next_url => 'https://test.sagepay.com/Simulator/VSPServerPaymentPage.asp?SageTransactionID={F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}', :id => 'tx_code', :vendor_name => 'sage_key'})
    end

    it 'passes if the signature matches' do
      @transaction.merge!(:vps_signature => 'DBCB54EB1128738F0C9E48600CBCF4DA')
      @transaction.signature_ok?.should be_true
    end

    it 'fails if the signature does not match' do
      @transaction.merge!(:vps_signature => 'CBCB54EB1128738F0C9E48600CBCF4DA')
      @transaction.signature_ok?.should be_false
    end

    it 'fails if the signature is unset' do
      @transaction.signature_ok?.should be_false
    end
  end

end


