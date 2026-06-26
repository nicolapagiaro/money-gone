# frozen_string_literal: true

module MovementHelpers
  def build_movement(attrs = {})
    MoneyGone::Domain::Movement.new(default_movement_attrs.merge(attrs))
  end

  def default_movement_attrs
    {
      id: 'm1',
      bank_id: 'a',
      booking_date: '2026-05-01',
      amount_signed: -10.0,
      description_raw: 'test',
      description_clean: 'test'
    }
  end
end
