if type -q grc
  set executables_path (path dirname (status --current-filename))/executables

  set -l execs (cat $executables_path)

  if set -q grc_plugin_ignore_execs
    for ignore_exec in $grc_plugin_ignore_execs
      set -l index (contains -i -- $ignore_exec $execs)
      if set -q index[1]
        set --erase execs[$index]
      end
    end
  end

  if set -q grc_plugin_execs
    if set -q grc_plugin_ignore_execs
      echo "Both grc_plugin_execs and grc_plugin_ignore_execs  have been provided. Ignoring the latter."
      set execs $grc_plugin_execs
    end
  end

  if set -q grc_plugin_extras
    set -a execs $grc_plugin_extras
  end

  set -l probe_path (string match -rv '^/mnt/' $PATH)

  for executable in $execs
    if PATH=$probe_path type -q $executable
      function $executable --inherit-variable executable --wraps=$executable
        grc.wrap $executable $argv
      end
    end
  end
else
  echo 'You need to install grc!'
end
