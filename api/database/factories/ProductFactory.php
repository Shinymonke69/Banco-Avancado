<?php

namespace Database\Factories;

use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->sentence(),
            'description' => fake()->sentences(asText: true),
            'image' => fake()->imageUrl(),
            'stock' => fake()->randomNumber(2),
            'price' => fake()->randomDigitNotZero() * fake()->randomNumber(2),
        ];
    }
}
