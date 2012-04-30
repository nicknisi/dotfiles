require 'rake'

# loosely based on zholman's install script

desc "create all the symlinks"
task :install do
  linkables = Dir.glob('*/**{.symlink}')

  linkables.each do |linkable|
    file = linkable.split('/').last.split('.symlink').last
    target = "#{ENV["HOME"]}/.#{file}"
    `ln -s "$PWD/#{linkable}" "#{target}"`
  end
end

task :default => 'install'
