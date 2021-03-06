require File.dirname(__FILE__) + '/spec_helper'

def m(name)
  v = mock(name)
  instance_variable_set("@#{name}", v)
end


describe SageParty::Transaction do
  describe 'urls' do
    context 'simulator server' do
      before do
        SageParty::Transaction.sage_pay_server(:simulator)
      end

      it 'registers with the simulator URL' do
        stub_request(:post, "https://test.sagepay.com/simulator/VSPServerGateway.asp?Service=VendorRegisterTx").
          to_return(:status => 200, :body => "expected url hit", :headers => {})
        SageParty::Transaction.raw_register.should == "expected url hit"
      end

      it 'authorises with the simulator URL' do
        stub_request(:post, "https://test.sagepay.com/simulator/VSPServerGateway.asp?Service=VendorAuthoriseTx").
          to_return(:status => 200, :body => "expected url hit", :headers => {})
        SageParty::Transaction.raw_authorise.should == "expected url hit"
      end
    end

    context 'test server' do
      before do
        SageParty::Transaction.sage_pay_server(:test)
      end

      it 'registers with the simulator URL' do
        stub_request(:post, "https://test.sagepay.com/gateway/service/vspserver-register.vsp").
          to_return(:status => 200, :body => "expected url hit", :headers => {})
        SageParty::Transaction.raw_register.should == "expected url hit"
      end

      it 'authorises with the simulator URL' do
        stub_request(:post, "https://test.sagepay.com/gateway/service/vspserver-authorise.vsp").
          to_return(:status => 200, :body => "expected url hit", :headers => {})
        SageParty::Transaction.raw_authorise.should == "expected url hit"
      end
    end

    context 'live server' do
      before do
        SageParty::Transaction.sage_pay_server(:live)
      end

      it 'registers with the simulator URL' do
        stub_request(:post, "https://live.sagepay.com/gateway/service/vspserver-register.vsp").
          to_return(:status => 200, :body => "expected url hit", :headers => {})
        SageParty::Transaction.raw_register.should == "expected url hit"
      end

      it 'authorises with the simulator URL' do
        stub_request(:post, "https://live.sagepay.com/gateway/service/vspserver-authorise.vsp").
          to_return(:status => 200, :body => "expected url hit", :headers => {})
        SageParty::Transaction.raw_authorise.should == "expected url hit"
      end
    end
  end

  describe 'authorising a AUTHENTICATED transaction' do
    let(:vendor_tx_code) { stub(:vendor_tx_code) }
    let(:vendor) { stub(:vendor) }
    let(:data) { {:VendorTxCode => vendor_tx_code, :Vendor => vendor} }

    it 'authorises with the data - include related fields and amount' do
      SageParty::Transaction.should_receive(:raw_authorise).with(data).and_return('')
      SageParty::Transaction.authorise_tx(data)
    end

    it 'parses the response' do
      SageParty::Transaction.stub!(:raw_authorise => "VPSProtocol=2.23\r\nStatus=OK\r\nStatusDetail=Server transaction authorised successfully.\r\nVPSTxId={F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}\r\nSecurityKey=YK4N4LO9PT\r\n")

      expected = SageParty::Transaction.new(
        :vps_protocol => '2.23', :status => 'OK',
        :status_detail => 'Server transaction authorised successfully.',
        :vps_tx_id => '{F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}',
        :security_key => 'YK4N4LO9PT', :id => vendor_tx_code, :vendor_name => vendor
      )

      SageParty::Transaction.authorise_tx(data).should == expected
    end
  end

  describe 'registering a transaction' do
    before do
      SageParty::Transaction.stub!(:raw_register => '')
      SageParty::Transaction.stub!(:tx_id => 'my_tx_id')
      @data = {:VendorTxCode => m(:tx_code), :Vendor => m(:vendor)}
    end

    it 'registers with the data' do
      SageParty::Transaction.should_receive(:raw_register).with(@data)
      SageParty::Transaction.register_tx(@data)
    end

    it 'parses the response' do
      SageParty::Transaction.stub!(:raw_register => "VPSProtocol=2.23\r\nStatus=OK\r\nStatusDetail=Server transaction registered successfully.\r\nVPSTxId={F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}\r\nSecurityKey=YK4N4LO9PT\r\nNextURL=https://test.sagepay.com/Simulator/VSPServerPaymentPage.asp?SageTransactionID={F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}")
      result = SageParty::Transaction.new({:vps_protocol => '2.23', :status => 'OK', :status_detail => 'Server transaction registered successfully.', :vps_tx_id => '{F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}', :security_key => 'YK4N4LO9PT', :next_url => 'https://test.sagepay.com/Simulator/VSPServerPaymentPage.asp?SageTransactionID={F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}', :id => @tx_code, :vendor_name => @vendor})

      SageParty::Transaction.register_tx(@data).should == result
    end
  end

  describe 'find' do
    it 'looks for the transaction' do
      SageParty::Transaction.should_receive(:get).with('foo')
      SageParty::Transaction.find('foo', 'bar')
    end

    context 'transaction can be found' do
      it 'returns the transaction' do
        transaction = mock(:transaction, :vps_tx_id => 'bar')
        SageParty::Transaction.stub!(:get => transaction)
        SageParty::Transaction.find('foo', 'bar').should == transaction
      end
    end

    context 'transaction cannot be found' do
      it 'returns a "null" transaction' do
        SageParty::Transaction.stub!(:get => nil)
        SageParty::Transaction.find('foo', 'bar').should_not be_exists
      end
    end

    context 'transaction VPSTxId mismatch' do
      it 'returns a "null" transaction' do
        SageParty::Transaction.stub!(:get => mock(:transaction, :vps_tx_id => mock))
        SageParty::Transaction.find('foo', 'bar').should_not be_exists
      end
    end
  end

  describe 'merge!' do
    before do
      @transaction = SageParty::Transaction.new('CardType' => m(:original_card_type), 'Status' => m(:status), 'SecurityKey' => m(:original_security_key))
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
      @transaction = SageParty::Transaction.new({:id => mock(:id)})
      @transaction.stub!(:notification_url => 'notify_url')
      @transaction.stub!(:signature_ok? => true)
    end

    def set_status(status)
      @transaction.merge!('Status' => status)
    end 

    def check_response(*args)
      @transaction.response.should == @transaction.send(:format_response, *args)
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
      @transaction = SageParty::Transaction.new({:vps_protocol => '2.23', :status => 'OK', :status_detail => 'Server transaction registered successfully.', :vps_tx_id => '{F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}', :security_key => 'YK4N4LO9PT', :next_url => 'https://test.sagepay.com/Simulator/VSPServerPaymentPage.asp?SageTransactionID={F2A9E367-AC15-4F5F-AB4C-D74B5A0EE8CF}', :id => 'tx_code', :vendor_name => 'sage_key'})
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


