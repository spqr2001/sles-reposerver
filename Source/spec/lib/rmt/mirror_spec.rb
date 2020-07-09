require 'rails_helper'

RSpec.describe RMT::Mirror do
  let(:logger) { RMT::Logger.new('/dev/null') }

  describe '#mirror_suma_product_tree' do
    subject(:command) { rmt_mirror.mirror_suma_product_tree(repository_url: 'https://scc.suse.com/suma/') }

    let(:rmt_mirror) do
      described_class.new(
        mirroring_base_dir: @tmp_dir,
        logger: logger,
        mirror_src: false
      )
    end

    around do |example|
      @tmp_dir = Dir.mktmpdir('rmt')
      example.run
      FileUtils.remove_entry(@tmp_dir)
    end

    context 'all is well', vcr: { cassette_name: 'mirroring_suma_product_tree' } do
      before do
        expect(logger).to receive(:info).with(/Mirroring SUSE Manager product tree to/).once
        expect(logger).to receive(:info).with(/↓ product_tree.json/).once
      end

      it 'downloads the suma product tree' do
        command
        content = File.read(File.join(@tmp_dir, 'suma/product_tree.json'))
        expect(Digest::SHA256.hexdigest(content)).to eq('7486026e9c1181affae5b21c9aa64637aa682fcdeacb099e213f0e8c7e86d85d')
      end
    end

    context 'with download exception' do
      before do
        expect_any_instance_of(RMT::Downloader).to receive(:download).and_raise(RMT::Downloader::Exception, "418 - I'm a teapot")
      end

      it 'raises mirroring exception' do
        expect { command }.to raise_error(RMT::Mirror::Exception, "Could not mirror SUSE Manager product tree with error: 418 - I'm a teapot")
      end
    end
  end

  describe '#mirror' do
    around do |example|
      @tmp_dir = Dir.mktmpdir('rmt')
      example.run
      FileUtils.remove_entry(@tmp_dir)
    end

    before do
      allow_any_instance_of(RMT::GPG).to receive(:verify_signature)
    end

    context 'without auth_token', vcr: { cassette_name: 'mirroring' } do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_repo/',
          local_path: '/dummy_repo'
        }
      end

      before do
        rmt_mirror.mirror(**mirror_params)
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'downloads drpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.drpm$/ }
        expect(rpm_entries.length).to eq(2)
      end
    end

    context 'without auth_token and with source packages', vcr: { cassette_name: 'mirroring_with_src' } do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: logger,
          mirror_src: mirror_src
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_repo_with_src/',
          local_path: '/dummy_repo'
        }
      end

      before do
        rmt_mirror.mirror(**mirror_params)
      end

      context 'when mirror_src is false' do
        let(:mirror_src) { false }

        it 'downloads rpm files' do
          rpm_entries = Dir.glob(File.join(@tmp_dir, 'dummy_repo', '**', '*.rpm'))
          expect(rpm_entries.length).to eq(2)
        end

        it 'downloads drpm files' do
          rpm_entries = Dir.glob(File.join(@tmp_dir, 'dummy_repo', '**', '*.drpm'))
          expect(rpm_entries.length).to eq(1)
        end
      end

      context 'when mirror_src is true' do
        let(:mirror_src) { true }

        it 'downloads rpm files' do
          rpm_entries = Dir.glob(File.join(@tmp_dir, 'dummy_repo', '**', '*.rpm'))
          expect(rpm_entries.length).to eq(4)
        end

        it 'downloads drpm files' do
          rpm_entries = Dir.glob(File.join(@tmp_dir, 'dummy_repo', '**', '*.drpm'))
          expect(rpm_entries.length).to eq(1)
        end
      end
    end

    context 'with auth_token', vcr: { cassette_name: 'mirroring_with_auth_token' } do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_repo/',
          local_path: '/dummy_repo',
          auth_token: 'repo_auth_token'
        }
      end

      before do
        expect(logger).to receive(:info).with(/Mirroring repository/).once
        expect(logger).to receive(:info).with('Repository metadata signatures are missing').once
        expect(logger).to receive(:info).with(/↓/).at_least(1).times
        rmt_mirror.mirror(**mirror_params)
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'downloads drpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.drpm$/ }
        expect(rpm_entries.length).to eq(2)
      end
    end

    context 'product with license and signatures', vcr: { cassette_name: 'mirroring_product' } do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      before do
        expect(logger).to receive(:info).with(/Mirroring repository/).once
        expect(logger).to receive(:info).with(/↓/).at_least(1).times
        rmt_mirror.mirror(**mirror_params)
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_product/product/')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'downloads drpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_product/product/')).select { |entry| entry =~ /\.drpm$/ }
        expect(rpm_entries.length).to eq(2)
      end

      it 'downloads repomd.xml signatures' do
        ['repomd.xml.key', 'repomd.xml.asc'].each do |file|
          expect(File.size(File.join(@tmp_dir, 'dummy_product/product/repodata/', file))).to be > 0
        end
      end

      it 'downloads product license' do
        ['directory.yast', 'license.txt', 'license.de.txt', 'license.ru.txt'].each do |file|
          expect(File.size(File.join(@tmp_dir, 'dummy_product/product.license/', file))).to be > 0
        end
      end
    end

    context 'when an error occurs' do
      let(:mirroring_dir) { @tmp_dir }
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: mirroring_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      context 'when mirroring_base_dir is not writable' do
        let(:mirroring_dir) { '/non/existent/path' }

        it 'raises exception', vcr: { cassette_name: 'mirroring_product' } do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception)
        end
      end

      context "when can't create tmp dir", vcr: { cassette_name: 'mirroring_product' } do
        before { allow(Dir).to receive(:mktmpdir).and_raise('mktmpdir exception') }
        it 'handles the exception' do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception)
        end
      end

      context "when can't download metadata", vcr: { cassette_name: 'mirroring_product' } do
        before do
          allow_any_instance_of(RMT::Downloader).to receive(:download).and_call_original
          expect_any_instance_of(RMT::Downloader).to receive(:download).with('repodata/repomd.xml').and_raise(RMT::Downloader::Exception, "418 - I'm a teapot")
        end
        it 'handles RMT::Downloader::Exception' do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception, "Error while mirroring metadata: 418 - I'm a teapot")
        end
      end

      context "when there's no licenses to download", vcr: { cassette_name: 'mirroring' } do
        let(:rmt_mirror) do
          described_class.new(
            mirroring_base_dir: @tmp_dir,
            logger: logger,
            mirror_src: false
          )
        end

        let(:mirror_params) do
          {
            repository_url: 'http://localhost/dummy_repo/',
            local_path: '/dummy_product/product/'
          }
        end

        it 'does not error out' do
          expect { rmt_mirror.mirror(**mirror_params) }.not_to raise_error
        end

        it 'does not create a product.licenses directory' do
          rmt_mirror.mirror(**mirror_params)
          expect(Dir).not_to exist(File.join(@tmp_dir, 'dummy_product', 'product.license'))
        end

        it 'removes the temporary licenses directory' do
          rmt_mirror.mirror(**mirror_params)
          tmpdir = rmt_mirror.instance_variable_get('@temp_licenses_dir')
          expect(Dir).not_to exist tmpdir
        end
      end

      context "when can't download some of the license files" do
        before do
          allow_any_instance_of(RMT::Downloader).to receive(:download_multi).and_wrap_original do |klass, *args|
            raise RMT::Downloader::Exception.new if args[0][0] =~ /license/
            klass.call(*args)
          end
        end
        it 'handles RMT::Downloader::Exception', vcr: { cassette_name: 'mirroring_product' } do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception, /Error while mirroring license:/)
        end
      end

      context "when can't parse metadata", vcr: { cassette_name: 'mirroring_product' } do
        before { allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_raise('Parse error') }
        it 'removes the temporary metadata directory' do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception, 'Error while mirroring metadata: Parse error')
          expect(File.exist?(rmt_mirror.instance_variable_get(:@temp_metadata_dir))).to be(false)
        end
      end

      context 'when Interrupt is raised', vcr: { cassette_name: 'mirroring_product' } do
        before { allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_raise(Interrupt.new) }
        it 'removes the temporary metadata directory' do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(Interrupt)
          expect(File.exist?(rmt_mirror.instance_variable_get(:@temp_metadata_dir))).to be(false)
        end
      end

      context "when can't download data", vcr: { cassette_name: 'mirroring_product' } do
        it 'handles RMT::Downloader::Exception' do
          allow_any_instance_of(RMT::Downloader).to receive(:finalize_download).and_wrap_original do |klass, *args|
            # raise the exception only for the RPMs/DRPMs
            raise(RMT::Downloader::Exception, "418 - I'm a teapot") if args[1] =~ /rpm$/
            klass.call(*args)
          end
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception, 'Error while mirroring data: Failed to download 6 files')
        end

        it 'handles RMT::ChecksumVerifier::Exception' do
          allow_any_instance_of(RMT::Downloader).to receive(:finalize_download).and_wrap_original do |klass, *args|
            # raise the exception only for the RPMs/DRPMs
            raise(RMT::ChecksumVerifier::Exception, "Checksum doesn't match") if args[1] =~ /rpm$/
            klass.call(*args)
          end
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception, 'Error while mirroring data: Failed to download 6 files')
        end
      end
    end

    context 'deduplication' do
      let(:rmt_source_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: RMT::Logger.new('/dev/null'),
          mirror_src: false
        )
      end

      let(:rmt_dedup_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: RMT::Logger.new('/dev/null'),
          mirror_src: false
        )
      end

      let(:mirror_params_source) do
        {
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      let(:mirror_params_dedup) do
        {
          repository_url: 'http://localhost/dummy_deduped_product/product/',
          local_path: '/dummy_deduped_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      let(:dedup_path) { File.join(@tmp_dir, 'dummy_deduped_product/product/') }
      let(:source_path) { File.join(@tmp_dir, 'dummy_product/product/') }

      shared_examples_for 'a deduplicated run' do |source_nlink, dedup_nlink, has_same_content|
        it 'downloads source rpm files' do
          rpm_entries = Dir.entries(File.join(source_path)).select { |entry| entry =~ /\.rpm$/ }
          expect(rpm_entries.length).to eq(4)
        end

        it 'deduplicates rpm files' do
          rpm_entries = Dir.entries(File.join(dedup_path)).select { |entry| entry =~ /\.rpm$/ }
          expect(rpm_entries.length).to eq(4)
        end


        it 'has correct content for deduplicated rpm files' do
          Dir.entries(File.join(dedup_path)).select { |entry| entry =~ /\.rpm$/ }.each do |file|
            if has_same_content
              expect(File.read(dedup_path + file)).to eq(File.read(source_path + file))
            else
              expect(File.read(dedup_path + file)).not_to eq(File.read(source_path + file))
            end
          end
        end

        it "source rpms have #{source_nlink} nlink" do
          Dir.entries(source_path).select { |entry| entry =~ /\.rpm$/ }.each do |file|
            expect(File.stat(source_path + file).nlink).to eq(source_nlink)
          end
        end

        it "dedup rpms have #{dedup_nlink} nlink" do
          Dir.entries(dedup_path).select { |entry| entry =~ /\.rpm$/ }.each do |file|
            expect(File.stat(dedup_path + file).nlink).to eq(dedup_nlink)
          end
        end

        it 'downloads source drpm files' do
          rpm_entries = Dir.entries(File.join(source_path)).select { |entry| entry =~ /\.drpm$/ }
          expect(rpm_entries.length).to eq(2)
        end

        it 'deduplicates drpm files' do
          rpm_entries = Dir.entries(File.join(dedup_path)).select { |entry| entry =~ /\.drpm$/ }
          expect(rpm_entries.length).to eq(2)
        end

        it 'has correct content for deduplicated drpm files' do
          Dir.entries(File.join(dedup_path)).select { |entry| entry =~ /\.drpm$/ }.each do |file|
            if has_same_content
              expect(File.read(dedup_path + file)).to eq(File.read(source_path + file))
            else
              expect(File.read(dedup_path + file)).not_to eq(File.read(source_path + file))
            end
          end
        end

        it "source drpms have #{source_nlink} nlink" do
          Dir.entries(source_path).select { |entry| entry =~ /\.drpm$/ }.each do |file|
            expect(File.stat(source_path + file).nlink).to eq(source_nlink)
          end
        end

        it "dedup drpms have #{dedup_nlink} nlink" do
          Dir.entries(dedup_path).select { |entry| entry =~ /\.drpm$/ }.each do |file|
            expect(File.stat(dedup_path + file).nlink).to eq(dedup_nlink)
          end
        end
      end

      context 'by copy' do
        before do
          deduplication_method(:copy)
          VCR.use_cassette 'mirroring_product_with_dedup' do
            rmt_source_mirror.mirror(**mirror_params_source)
            rmt_dedup_mirror.mirror(**mirror_params_dedup)
          end
        end

        it_behaves_like 'a deduplicated run', 1, 1, true
      end

      context 'by hardlink' do
        before do
          deduplication_method(:hardlink)
          VCR.use_cassette 'mirroring_product_with_dedup' do
            rmt_source_mirror.mirror(**mirror_params_source)
            rmt_dedup_mirror.mirror(**mirror_params_dedup)
          end
        end

        it_behaves_like 'a deduplicated run', 2, 2, true
      end

      context 'by copy with corruption' do
        before do
          deduplication_method(:copy)
          VCR.use_cassette 'mirroring_product_with_dedup' do
            rmt_source_mirror.mirror(**mirror_params_source)
            Dir.entries(source_path).select { |entry| entry =~ /(\.drpm|\.rpm)$/ }.each do |filename|
              File.open(source_path + filename, 'w') { |f| f.write('corruption') }
            end
            rmt_dedup_mirror.mirror(**mirror_params_dedup)
          end
        end

        it_behaves_like 'a deduplicated run', 1, 1, false
      end
    end

    context 'with cached metadata' do
      let(:mirroring_dir) do
        FileUtils.cp_r(file_fixture('dummy_product'), File.join(@tmp_dir, 'dummy_product'))
        @tmp_dir
      end
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: mirroring_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      let(:timestamp) { 'Mon, 01 Jan 2018 10:10:00 GMT' }

      before do
        expect_any_instance_of(RMT::Downloader).to receive(:get_cache_timestamp).at_least(:once) { timestamp }
        FileUtils.touch "#{mirroring_dir}/dummy_product/product/repodata/repomd.xml", mtime: Time.parse(timestamp).utc

        VCR.use_cassette 'mirroring_product_with_cached_metadata' do
          rmt_mirror.mirror(**mirror_params)
        end
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_product/product/')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'preserves metadata timestamps' do
        expect(File.mtime("#{mirroring_dir}/dummy_product/product/repodata/repomd.xml")).to eq(Time.parse(timestamp).utc)
      end
    end
  end

  describe '#replace_directory' do
    subject(:replace_directory) { rmt_mirror.send(:replace_directory, source_dir, destination_dir) }

    let(:rmt_mirror) do
      described_class.new(
        mirroring_base_dir: @tmp_dir,
        logger: logger,
        mirror_src: false
      )
    end

    let(:source_dir) { '/tmp/temp-repo-dir' }
    let(:destination_dir) { '/var/www/repo/product.license' }
    let(:old_dir) { '/var/www/repo/.old_product.license' }

    context 'when the old directory exists' do
      before do
        expect(Dir).to receive(:exist?).with(old_dir).and_return(true)
        expect(Dir).to receive(:exist?).with(destination_dir).and_return(false)
      end

      it 'removes it, moves src to dst and sets permissions' do
        expect(FileUtils).to receive(:remove_entry).with(old_dir)
        expect(FileUtils).to receive(:mv).with(source_dir, destination_dir)
        expect(FileUtils).to receive(:chmod).with(0o755, destination_dir)
        replace_directory
      end
    end

    context 'when the destination directory already exists' do
      before do
        expect(Dir).to receive(:exist?).with(old_dir).and_return(false)
        expect(Dir).to receive(:exist?).with(destination_dir).and_return(true)
      end

      it 'renames it as .old, moves src to dst and sets permissions' do
        expect(FileUtils).to receive(:mv).with(destination_dir, old_dir)
        expect(FileUtils).to receive(:mv).with(source_dir, destination_dir)
        expect(FileUtils).to receive(:chmod).with(0o755, destination_dir)
        replace_directory
      end
    end

    context 'when an error is encountered' do
      it 'raises RMT::Mirror::Exception' do
        expect(FileUtils).to receive(:mv).and_raise(Errno::ENOENT)
        expect { replace_directory }.to raise_error(
          RMT::Mirror::Exception,
          "Error while moving directory #{source_dir} to #{destination_dir}: No such file or directory"
        )
      end
    end
  end

  context 'when GPG signature is incomplete', vcr: { cassette_name: 'mirroring_with_auth_token' } do
    let(:rmt_mirror) do
      described_class.new(
        mirroring_base_dir: @tmp_dir,
        logger: logger,
        mirror_src: false
      )
    end

    let(:mirror_params) do
      {
        repository_url: 'http://localhost/dummy_repo/',
        local_path: '/dummy_repo',
        auth_token: 'repo_auth_token'
      }
    end

    around do |example|
      @tmp_dir = Dir.mktmpdir('rmt')
      example.run
      FileUtils.remove_entry(@tmp_dir)
    end

    context 'when signatures do not exist' do
      it 'mirrors as normal' do
        expect(logger).to receive(:info).with(/Mirroring repository/).once
        expect(logger).to receive(:info).with('Repository metadata signatures are missing').once
        expect(logger).to receive(:info).with(/↓/).at_least(1).times

        allow_any_instance_of(RMT::Downloader).to receive(:finalize_download).and_wrap_original do |klass, *args|
          if args[1] == 'repodata/repomd.xml.key'
            raise RMT::Downloader::Exception.new('HTTP request failed', 404)
          else
            klass.call(*args)
          end
        end

        rmt_mirror.mirror(**mirror_params)
      end
    end

    context 'when files fail to download with errors other than 404' do
      it 'raises RMT::Mirror::Exception' do
        expect(logger).to receive(:info).with(/Mirroring repository/).once
        expect(logger).to receive(:info).with(/↓/).at_least(1).times

        allow_any_instance_of(RMT::Downloader).to receive(:download).and_wrap_original do |klass, *args|
          if args[0] == 'repodata/repomd.xml.key'
            '/foo/repomd.xml.key'
          elsif args[0] == 'repodata/repomd.xml.asc'
            raise RMT::Downloader::Exception.new('HTTP request failed', 502)
          else
            klass.call(*args)
          end
        end

        expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(
          RMT::Mirror::Exception,
           'Error while mirroring metadata: Failed to get repository metadata signatures with HTTP code 502'
        )
      end
    end
  end
end
