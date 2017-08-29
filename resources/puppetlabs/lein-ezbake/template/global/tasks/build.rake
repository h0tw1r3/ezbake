namespace :pl do
  desc "do a local build"
  task :local_build => "pl:fetch" do
    # If we have a dirty source, bail, because changes won't get reflected in
    # the package builds
    Pkg::Util::Version.fail_on_dirty_source

    Pkg::Util::RakeUtils.invoke_task("package:tar")
    # where we want the packages to be copied to for the local build
    nested_output = '../../../output'
    pkg_path = '../pkg'
    FileUtils.mv(Dir.glob("pkg/*.gz").join(''), FileUtils.pwd)
    # unpack the tarball we made during the build step
    `tar xf #{Dir.glob("*.gz").join('')}`
    Dir.chdir("#{Pkg::Config.project}-#{Pkg::Config.version}") do
      Pkg::Config.final_mocks.split(" ").each do |mock|
        platform = mock.split('-')[1..-2].join('-')
        platform_path = platform.gsub(/\-/, '')
        os, ver = /([a-zA-Z]+)(\d+)/.match(platform_path).captures
        platform_path = "#{os}/#{ver}"
        `bash controller.sh #{os} #{ver}`
        # carry forward defaults from mock.rake
        repo = Pkg::Config.yum_repo_name || 'products'
        # We want to include the arches for el/sles/fedora paths
        ['x86_64', 'i386'].each do |arch|
          target_dir = "#{pkg_path}/#{platform_path}/#{repo}/#{arch}"
          FileUtils.mkdir_p(target_dir) unless File.directory?(target_dir)
          FileUtils.cp(Dir.glob("*#{os}#{ver}*.rpm"), target_dir)
        end
      end
      Pkg::Config.cows.split(" ").each do |cow|
        # carry forward defaults from Packaging::Deb::Repo
        repo = Pkg::Config.apt_repo_name || 'main'
        platform = cow.split('-')[1..-2].join('-')
        platform_path = "deb/#{platform}/#{repo}"
        FileUtils.mkdir_p("#{pkg_path}/#{platform_path}") unless File.directory?("#{pkg_path}/#{platform_path}")
        # there's no differences in packaging for deb vs ubuntu so picking debian
        # if that changes we'll need to fix that
        `bash controller.sh debian #{platform}`
        FileUtils.cp(Dir.glob("*#{platform}*.deb"), "#{pkg_path}/#{platform_path}")
      end
      FileUtils.cp_r(pkg_path, nested_output)
    end
  end
end