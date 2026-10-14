<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class OrderSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $customers = \App\Models\Customer::limit(100)
            ->get()
            ->pluck('id')
            ->toArray();

        $status = fake()->randomElement(['open', 'paid']);
        $paidAt = $status === 'paid' ? fake()->dateTimeBetween(
            startDate: '-1 day',
        ) : null ;

        $fakeData = fn() => ([
            'customer_id' => fake()->randomElement($customers),
            'status' => fake()->randomElement(['pending', 'paid']),
            'paid_at' => $paidAt,
            'total' => fake()->randomFloat(2, 10, 500),
            'items' => [
                [
                    'product_id' => (string) new \MongoDB\BSON\ObjectId(),
                    'product_name' => fake()->word(),
                    'product_price' => fake()->randomFloat(2, 10, 100),
                    'quantity' => fake()->numberBetween(1, 5),
                ],
                [
                    'product_id' => (string) new \MongoDB\BSON\ObjectId(),
                    'product_name' => fake()->word(),
                    'product_price' => fake()->randomFloat(2, 10, 100),
                    'quantity' => fake()->numberBetween(1, 5),
                ]
            ]
        ]);

        $inserted = 0;
        while ($inserted < 100_000) {
            $orders = [];
            for ($i = 0; $i < 1000; $i++) {
                $orders[] = $fakeData();
            }

            // Forçando o uso da connection do MongoDB pelo facade DB
            DB::connection('mongodb')->table('orders')->insert($orders);

            $inserted += count($orders);
        }
    }
}
