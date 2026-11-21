package com.orderly.app

import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.ListView
import androidx.appcompat.app.AppCompatActivity
import kotlin.concurrent.thread

class MainActivity : AppCompatActivity() {
    private val repository = OrdersRepository()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val list = ListView(this)
        setContentView(list)

        thread {
            val rows = repository.ordersFor("cus_demo").map { "${it.id}  ${it.status}  ${it.formattedTotal}" }
            runOnUiThread { list.adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, rows) }
        }
    }
}
