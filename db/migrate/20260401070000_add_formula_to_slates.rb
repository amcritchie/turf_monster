class AddFormulaToSlates < ActiveRecord::Migration[7.2]
  def change
    add_column :slates, :formula_a, :float
    add_column :slates, :formula_line_exp, :float
    add_column :slates, :formula_prob_exp, :float
    add_column :slates, :formula_mult_base, :float
    add_column :slates, :formula_mult_scale, :float
    add_column :slates, :formula_goal_base, :float
    add_column :slates, :formula_goal_scale, :float
  end
end
