<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use MongoDB\Laravel\Eloquent\Model;

class Product extends Model
{
    /** @use HasFactory<\Database\Factories\ProductFactory> */
    use HasFactory;
    protected $connection = 'mongodb';
    protected $fillable = [
        'name',
        'description',
        'image',
        'stock',
        'price',
        'attributes',
    ];
    protected function casts()
    {
        return [
            'attributes' => 'array',
        ];
    }
}