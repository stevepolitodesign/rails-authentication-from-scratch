class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      # Prevent blank values
      t.string :email, null: false

      t.timestamps
    end

    # Enforce unique values
    # https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_index
    add_index :users, :email, unique: true
  end
end
