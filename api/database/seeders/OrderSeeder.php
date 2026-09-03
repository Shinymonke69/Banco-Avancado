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
            'paid_at' => $paidAt, // ? $paidAt->toISOString() : null,
            'total' => fake()->randomFloat(
                nbMaxDecimals: 2,
                min: 10,
                max: 500,
            ),
        ]);

        $inserted = 0;
        while ($inserted < 100_000) {
            $orders = [];
            for ($i = 0; $i < 1000; $i++) {
                $orders[] = $fakeData();
            }

            DB::transaction(function() use($orders) {
                DB::table('orders')->insert($orders);
            });

            $inserted += count($orders);
        }
    }
}
