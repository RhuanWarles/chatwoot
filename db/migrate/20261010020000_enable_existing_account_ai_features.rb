class EnableExistingAccountAiFeatures < ActiveRecord::Migration[7.2]
  # Appended slots 11 and 12 in feature_flags_ext_1; existing slots stay intact.
  AI_FEATURE_MASK = (1 << 10) | (1 << 11)

  def up
    execute "UPDATE accounts SET feature_flags_ext_1 = feature_flags_ext_1 | #{AI_FEATURE_MASK}"
  end

  def down
    execute "UPDATE accounts SET feature_flags_ext_1 = feature_flags_ext_1 & ~#{AI_FEATURE_MASK}"
  end
end
