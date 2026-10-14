<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use MongoDB\Laravel\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Order extends Model
{
    /** @use HasFactory<\Database\Factories\OrderFactory> */
    use HasFactory, SoftDeletes;
    
    protected $connection = 'mongodb';

    protected $fillable = [
        'customer_id',
        'total',
        'status',
        'paid_at',
        'items',
    ];

    public function items()
    {
        return $this->embedsMany(OrderItem::class);
    }
}
