require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Bsd',
         :unless => Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:bsd) }

  before :each do
    Puppet::Type.type(:service).stubs(:defaultprovider).returns provider_class
    Facter.stubs(:value).with(:operatingsystem).returns :netbsd
    Facter.stubs(:value).with(:osfamily).returns 'NetBSD'
    provider_class.stubs(:defpath).returns('/etc/rc.conf.d')
    @provider = provider_class.new
    @provider.stubs(:initscript)
  end

  context "#instances" do
    it "should have an instances method" do
      expect(provider_class).to respond_to :instances
    end

    it "should use defpath" do
      expect(provider_class.instances).to be_all { |provider| provider.get(:path) == provider_class.defpath }
    end
  end

  context "#disable" do
    it "should have a disable method" do
      expect(@provider).to respond_to(:disable)
    end

    it "should remove a service file to disable" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      Puppet::FileSystem.stubs(:exist?).with('/etc/rc.conf.d/sshd').returns(true)
      Puppet::FileSystem.expects(:exist?).with('/etc/rc.conf.d/sshd').returns(true)
      File.stubs(:delete).with('/etc/rc.conf.d/sshd')
      provider.disable
    end

    it "should not remove a service file if it doesn't exist" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      File.stubs(:exist?).with('/etc/rc.conf.d/sshd').returns(false)
      Puppet::FileSystem.expects(:exist?).with('/etc/rc.conf.d/sshd').returns(false)
      provider.disable
    end
  end

  context "#enable" do
    it "should have an enable method" do
      expect(@provider).to respond_to(:enable)
    end

    it "should set the proper contents to enable" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      Dir.stubs(:mkdir).with('/etc/rc.conf.d')
      fh = stub 'fh'
      File.stubs(:open).with('/etc/rc.conf.d/sshd', File::WRONLY | File::APPEND | File::CREAT, 0644).yields(fh)
      fh.expects(:<<).with("sshd_enable=\"YES\"\n")
      provider.enable
    end

    it "should set the proper contents to enable when disabled" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      Dir.stubs(:mkdir).with('/etc/rc.conf.d')
      File.stubs(:read).with('/etc/rc.conf.d/sshd').returns("sshd_enable=\"NO\"\n")
      fh = stub 'fh'
      File.stubs(:open).with('/etc/rc.conf.d/sshd', File::WRONLY | File::APPEND | File::CREAT, 0644).yields(fh)
      fh.expects(:<<).with("sshd_enable=\"YES\"\n")
      provider.enable
    end
  end

  context "#enabled?" do
    it "should have an enabled? method" do
      expect(@provider).to respond_to(:enabled?)
    end

    it "should return false if the service file does not exist" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      Puppet::FileSystem.stubs(:exist?).with('/etc/rc.conf.d/sshd').returns(false)
      # File.stubs(:read).with('/etc/rc.conf.d/sshd').returns("sshd_enable=\"NO\"\n")
      expect(provider.enabled?).to eq(:false)
    end

    it "should return true if the service file exists" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      Puppet::FileSystem.stubs(:exist?).with('/etc/rc.conf.d/sshd').returns(true)
      # File.stubs(:read).with('/etc/rc.conf.d/sshd').returns("sshd_enable=\"YES\"\n")
      expect(provider.enabled?).to eq(:true)
    end
  end

  context "#startcmd" do
    it "should have a startcmd method" do
      expect(@provider).to respond_to(:startcmd)
    end

    it "should use the supplied start command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :start => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end

    it "should start the serviced directly otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', :onestart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.start
    end
  end

  context "#stopcmd" do
    it "should have a stopcmd method" do
      expect(@provider).to respond_to(:stopcmd)
    end

    it "should use the supplied stop command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :stop => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end

    it "should stop the serviced directly otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', :onestop], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.stop
    end
  end
end
