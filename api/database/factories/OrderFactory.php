<?php

namespace Database\Factories;

use App\Models\Customer;
use App\Models\Order;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Order>
 */
class OrderFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $status = fake()->randomElement(['open', 'paid']);
        $paidAt = $status === 'paid' ? fake()->dateTimeBetween(
            startDate: '-1 month',
        ) : null ;

        return [
            'customer_id' => Customer::factory()->create()->id,
            'total' => fake()->randomFloat(
                nbMaxDecimals: 2,
                min: 10,
                max: 500,
            ),
            'status' => $status,
            'paid_at' => $paidAt,
        ];
    }
}
