require 'rake'

# loosely based on zholman's install script

def linkables
  linkables = Dir.glob('**/*.symlink')
  linkables.each do |linkable|
    file = linkable.split('/').last.split('.symlink').last
    target = "#{ENV["HOME"]}/.#{file}"
    yield linkable, file, target if block_given?
  end
end

desc "make a backup of all files that will be replaced (if they exist)"
task :backup do
  linkables do |linkable, file, target|
    if File.exists?(target) || File.symlink?(target)
      `mv "$HOME/.#{file}" "$HOME/.#{file}.backup"`
    end
  end
end

desc "restore the backups"
task :restore do
  linkables do |linkable, file, target|
    if File.exists?("#{ENV['HOME']}/.#{file}.backup")
      `mv "$HOME/.#{file}.backup" "$HOME/.#{file}"`
    end
  end
end

desc "create all the symlinks"
task :install do
  linkables do |linkable, file, target|
    unless File.exists?(target)
      `ln -s "$PWD/#{linkable}" "#{target}"`
    end
  end
end

desc "remove all files added"
task :uninstall do
  linkables do |linkable, file, target|
    if File.symlink?(target)
      FileUtils.rm(target)
    end
  end
end

task :default => 'install'
