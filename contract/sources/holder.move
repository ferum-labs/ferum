//
// public entry fun add_order_entry<I, Q>(
//     owner: &signer,
//     side: u8,
//     type: u8,
//     price: u64,
//     qty: u64,
//     clientOrderID: String,
// ) acquires OrderBook, UserMarketInfo {
//     let book = borrow_global<OrderBook<I, Q>>(get_market_addr<I, Q>());
//     let priceFixedPoint = from_u64(price, book.qDecimals);
//     let qtyFixedPoint = from_u64(qty, book.iDecimals);
//
//     add_order<I, Q>(owner, side, type, priceFixedPoint, qtyFixedPoint, clientOrderID);
// }
//
// public entry fun swap_entry<I, Q>(
//     owner: &signer,
//     side: u8,
//     price: u64,
//     qty: u64,
//     clientOrderID: String,
// ) acquires OrderBook, UserMarketInfo {
//     let book = borrow_global<OrderBook<I, Q>>(get_market_addr<I, Q>());
//     let priceFixedPoint = from_u64(price, book.qDecimals);
//     let qtyFixedPoint = if (side == SIDE_BUY) {
//         from_u64(qty, book.qDecimals)
//     } else if (side == SIDE_SELL) {
//         from_u64(qty, book.iDecimals)
//     } else {
//         abort ERR_INVALID_SIDE
//     };
//
//     swap<I, Q>(owner, side, priceFixedPoint, qtyFixedPoint, clientOrderID);
// }
//
// public entry fun cancel_order_entry<I, Q>(owner: &signer, orderIDCounter: u128) acquires OrderBook {
//     let id = OrderID {
//         owner: address_of(owner),
//         counter: orderIDCounter,
//     };
//     cancel_order_internal<I, Q>(owner, id, sentinal_user_identifier());
// }
//
// public entry fun cancel_all_orders_for_owner_entry<I, Q>(owner: &signer) acquires OrderBook {
//     let ownerAddr = address_of(owner);
//
//     let bookAddr = get_market_addr<I, Q>();
//     assert!(exists<OrderBook<I, Q>>(bookAddr), ERR_BOOK_DOES_NOT_EXIST);
//     let book = borrow_global_mut<OrderBook<I, Q>>(bookAddr);
//
//     if (!table::contains(&book.signerToOrders, ownerAddr)) {
//         // We can assume this means the user didn't place any orders so there is no work to do.
//         return
//     };
//
//     let orderIDs = table::remove(&mut book.signerToOrders, ownerAddr);
//     let ordersLength = vector::length(&orderIDs);
//     let i = 0;
//     while (i < ordersLength) {
//         let orderID = vector::pop_back(&mut orderIDs);
//         let order = table::borrow_mut(&mut book.orderMap, orderID);
//
//         assert!(order.id.owner == ownerAddr, ERR_NOT_OWNER);
//
//         mark_cancelled_order(
//             &mut book.finalizeEvents,
//             order,
//             CANCEL_AGENT_USER,
//         );
//
//         let order = table::remove(&mut book.orderMap, order.id);
//         settle_unsettled_collateral(&mut order);
//         let orderTree = if (order.metadata.side == SIDE_BUY) {
//             &mut book.buys
//         } else if (order.metadata.side == SIDE_SELL) {
//             &mut book.sells
//         } else {
//             abort ERR_INVALID_SIDE
//         };
//         order_store::delete_value(orderTree, fixed_point_64::value(order.metadata.price), order.id);
//         table::add(&mut book.finalizedOrderMap, order.id, order);
//
//         i = i + 1;
//     };
//     vector::destroy_empty(orderIDs);
// }
//
// //
// // Public functions.
// //
//
// public fun add_order<I, Q>(
//     owner: &signer,
//     side: u8,
//     type: u8,
//     price: FixedPoint64,
//     qty: FixedPoint64,
//     clientOrderID: String,
// ): OrderID acquires OrderBook, UserMarketInfo {
//     add_order_internal<I, Q>(owner, side, type, price, qty, clientOrderID, sentinal_user_identifier())
// }
//
// public fun add_order_for_user<I, Q>(
//     owner: &signer,
//     userIdentifier: UserIdentifier,
//     side: u8,
//     type: u8,
//     price: FixedPoint64,
//     qty: FixedPoint64,
//     clientOrderID: String,
// ): OrderID acquires OrderBook, UserMarketInfo {
//     assert!(is_user_identifier_valid(&userIdentifier), ERR_INVALID_USER_IDENTIFIER);
//
//     add_order_internal<I, Q>(
//         owner,
//         side,
//         type,
//         price,
//         qty,
//         clientOrderID,
//         userIdentifier,
//     )
// }
//
// public fun swap<I, Q>(
//     owner: &signer,
//     side: u8,
//     price: FixedPoint64,
//     qty: FixedPoint64,
//     clientOrderID: String,
// ): OrderID acquires OrderBook, UserMarketInfo {
//     add_order<I, Q>(owner, side, TYPE_IOC, price, qty, clientOrderID)
// }
//
// public fun cancel_order_for_user<I, Q>(
//     signer: &signer,
//     userIdentifier: UserIdentifier,
//     orderOwner: address,
//     orderIDCounter: u128,
// ) acquires OrderBook {
//     let id = OrderID {
//         owner: orderOwner,
//         counter: orderIDCounter,
//     };
//     cancel_order_internal<I, Q>(signer, id, userIdentifier)
// }
//
// public fun get_order_collateral_amount<I, Q>(
//     side: u8,
//     price: FixedPoint64,
//     qty: FixedPoint64,
// ): (FixedPoint64, FixedPoint64) {
//     if (side == SIDE_BUY) {
//         (
//             fixed_point_64::multiply_round_up(price, qty),
//             fixed_point_64::zero(),
//         )
//     } else if (side == SIDE_SELL) {
//         (
//             fixed_point_64::zero(),
//             qty,
//         )
//     } else {
//         abort ERR_INVALID_SIDE
//     }
// }
//
// public fun get_market_decimals<I, Q>(): (u8, u8) acquires OrderBook {
//     let book = borrow_global<OrderBook<I, Q>>(get_market_addr<I, Q>());
//     (book.iDecimals, book.qDecimals)
// }
//
// public fun get_market_addr<I, Q>(): address {
//     admin::get_market_addr<I, Q>()
// }
//
// //
// // Private functions.
// //
//
// fun add_order_internal<I, Q>(
//     owner: &signer,
//     side: u8,
//     type: u8,
//     price: FixedPoint64,
//     qty: FixedPoint64,
//     clientOrderID: String,
//     userIdentifier: UserIdentifier,
// ): OrderID acquires OrderBook, UserMarketInfo {
//     let bookAddr = get_market_addr<I, Q>();
//     assert!(exists<OrderBook<I, Q>>(bookAddr), ERR_BOOK_DOES_NOT_EXIST);
//     validate_coins<I, Q>();
//     create_user_info_if_needed<I, Q>(owner);
//
//     let ownerAddr = address_of(owner);
//     let book = borrow_global_mut<OrderBook<I, Q>>(bookAddr);
//
//     // Validates that the decimal places don't exceed the max decimal places allowed by the market.
//     fixed_point_64::to_u128(price, book.qDecimals);
//     fixed_point_64::to_u128(qty, book.iDecimals);
//
//     // Before adding taker only orders, check to make sure it crosses the spread. If it doesn't, immediately cancel.
//     if (type == TYPE_IOC || type == TYPE_FOK) {
//         // TODO: for a FOK order, we need to check to make sure there is enough liquidity
//         // to fill the order at its price point.
//         if (side == SIDE_SELL) {
//             if (is_empty(&book.buys)) {
//                 // It doesn't cross the spread, cancel.
//                 return create_cancelled_taker_order(book, ownerAddr, side, type, price, qty, clientOrderID, userIdentifier)
//             };
//             let topOfBook= fixed_point_64::new_u128(max_key(&book.buys));
//             if (fixed_point_64::gt(price, topOfBook)) {
//                 // It doesn't cross the spread, cancel.
//                 return create_cancelled_taker_order(book, ownerAddr, side, type, price, qty, clientOrderID, userIdentifier)
//             }
//         } else if (side == SIDE_BUY) {
//             if (is_empty(&book.sells)) {
//                 // It doesn't cross the spread, cancel.
//                 return create_cancelled_taker_order(book, ownerAddr, side, type, price, qty, clientOrderID, userIdentifier)
//             };
//             let topOfBook= fixed_point_64::new_u128(min_key(&book.sells));
//             if (fixed_point_64::lt(price, topOfBook)) {
//                 std::debug::print(&topOfBook);
//                 std::debug::print(&price);
//                 // It doesn't cross the spread, cancel.
//                 return create_cancelled_taker_order(book, ownerAddr, side, type, price, qty, clientOrderID, userIdentifier)
//             }
//         } else {
//             abort ERR_INVALID_SIDE
//         };
//     };
//     // TODO: add handling for POST only orders.
//
//     let (buyCollateral, sellCollateral) = obtain_order_collateral<I, Q>(
//         owner,
//         side,
//         price,
//         qty,
//     );
//
//     let orderID = gen_order_id<I, Q>(ownerAddr);
//     let order = Order<I, Q>{
//         id: orderID,
//         buyCollateral,
//         sellCollateral,
//         metadata: OrderMetadata{
//             instrumentType: type_info::type_of<I>(),
//             quoteType: type_info::type_of<Q>(),
//             side,
//             price,
//             remainingQty: qty,
//             type,
//             originalQty: qty,
//             status: STATUS_PENDING,
//             clientOrderID,
//             executionCounter: 0,
//             updateCounter: 0,
//             userIdentifier,
//         },
//     };
//     if (!table::contains(&book.signerToOrders, ownerAddr)) {
//         table::add(&mut book.signerToOrders, ownerAddr, vector::empty());
//     };
//     let orderIDs = table::borrow_mut(&mut book.signerToOrders, ownerAddr);
//     vector::push_back(orderIDs, orderID);
//     add_order_to_book<I, Q>(book, order);
//     orderID
// }
//
// fun cancel_order_internal<I, Q>(owner: &signer, orderID: OrderID, userIdentifier: UserIdentifier) acquires OrderBook {
//     let bookAddr = get_market_addr<I, Q>();
//     assert!(exists<OrderBook<I, Q>>(bookAddr), ERR_BOOK_DOES_NOT_EXIST);
//
//     let ownerAddr = address_of(owner);
//     let book = borrow_global_mut<OrderBook<I, Q>>(bookAddr);
//     assert!(table::contains(&book.orderMap, orderID), ERR_UNKNOWN_ORDER);
//     let order = table::borrow_mut(&mut book.orderMap, orderID);
//
//     if (is_user_identifier_valid(&order.metadata.userIdentifier)) {
//         assert!(userIdentifier == order.metadata.userIdentifier, ERR_NOT_CORRECT_PROTOCOL);
//     } else {
//         assert!(ownerAddr == order.id.owner, ERR_NOT_OWNER);
//     };
//
//     mark_cancelled_order(
//         &mut book.finalizeEvents,
//         order,
//         CANCEL_AGENT_USER,
//     );
//
//     let order = table::remove(&mut book.orderMap, order.id);
//     settle_unsettled_collateral(&mut order);
//     let orderTree = if (order.metadata.side == SIDE_BUY) {
//         &mut book.buys
//     } else if (order.metadata.side == SIDE_SELL) {
//         &mut book.sells
//     } else {
//         abort ERR_INVALID_SIDE
//     };
//     order_store::delete_value(orderTree, fixed_point_64::value(order.metadata.price), order.id);
//
//     let signerOrderIDs = table::borrow_mut(&mut book.signerToOrders, order.id.owner);
//     let (exists, orderIDIdx) = vector::index_of(signerOrderIDs, &order.id);
//     assert!(exists, ERR_SIGNER_NOT_IN_MAP);
//     vector::swap_remove(signerOrderIDs, orderIDIdx);
//     table::add(&mut book.finalizedOrderMap, order.id, order);
// }
//
// fun gen_order_id<I, Q>(owner: address): OrderID acquires UserMarketInfo {
//     let market_info = borrow_global_mut<UserMarketInfo<I, Q>>(owner);
//     let counter = market_info.idCounter;
//     market_info.idCounter = market_info.idCounter + 1;
//     OrderID {
//         owner,
//         counter,
//     }
// }
//
// fun create_cancelled_taker_order<I, Q>(
//     book: &mut OrderBook<I, Q>,
//     ownerAddr: address,
//     side: u8,
//     type: u8,
//     price: FixedPoint64,
//     qty: FixedPoint64,
//     clientOrderID: String,
//     userIdentifier: UserIdentifier,
// ): OrderID acquires UserMarketInfo {
//     let orderID = gen_order_id<I, Q>(ownerAddr);
//     let order = Order<I, Q>{
//         id: orderID,
//         buyCollateral: coin::zero(),
//         sellCollateral: coin::zero(),
//         metadata: OrderMetadata{
//             instrumentType: type_info::type_of<I>(),
//             quoteType: type_info::type_of<Q>(),
//             side,
//             price,
//             remainingQty: qty,
//             type,
//             originalQty: qty,
//             status: STATUS_CANCELLED,
//             clientOrderID,
//             executionCounter: 0,
//             updateCounter: 1,
//             userIdentifier,
//         },
//     };
//     validate_order(&order);
//     emit_order_created_event(book, &order);
//     let agent = if (type == TYPE_IOC) {
//         CANCEL_AGENT_IOC
//     } else if (type == TYPE_FOK) {
//         CANCEL_AGENT_FOK
//     } else {
//         abort ERR_INVALID_TYPE
//     };
//     mark_cancelled_order(&mut book.finalizeEvents, &mut order, agent);
//     table::add(&mut book.finalizedOrderMap, order.id, order);
//     orderID
// }
//
// fun add_order_to_book<I, Q>(book: &mut OrderBook<I, Q>, order: Order<I, Q>) {
//     validate_order(&order);
//     emit_order_created_event(book, &order);
//
//     // Match order as much as we can against the book.
//     match(book, &mut order);
//
//     if (is_order_finalized(&order)) {
//         // The order is finalized, we can now move it to the finalized map.
//         settle_unsettled_collateral(&mut order);
//         table::add(&mut book.finalizedOrderMap, order.id, order);
//     } else {
//         if (order.metadata.type == TYPE_IOC) {
//             // Cancel remaing portion of taker only orders.
//             mark_cancelled_order(&mut book.finalizeEvents, &mut order, CANCEL_AGENT_IOC);
//             settle_unsettled_collateral(&mut order);
//             table::add(&mut book.finalizedOrderMap, order.id, order);
//         } else if (order.metadata.type == TYPE_RESTING) {
//             // For other orders, add them to the book.
//             let orderTree = if (order.metadata.side == SIDE_BUY) {
//                 &mut book.buys
//             } else if (order.metadata.side == SIDE_SELL) {
//                 &mut book.sells
//             } else {
//                 abort ERR_INVALID_SIDE
//             };
//             order_store::insert(orderTree, fixed_point_64::value(order.metadata.price), order.id);
//             let orderMap = &mut book.orderMap;
//             table::add(orderMap, order.id, order);
//         } else {
//             // POST orders should never reach this point because we add them directly into the book and skip
//             // any matching.
//             // FOK orders should never reach this point because they either finalize completely or are cancelled
//             // immediately.
//             abort ERR_INVALID_TYPE
//         }
//     };
//
//     // Update the price before returning.
//     let data = get_quote(book);
//     emit_event(&mut book.priceUpdateEvents, PriceUpdateEvent{
//         data,
//     });
// }
//
// fun match<I, Q>(book: &mut OrderBook<I, Q>, order: &mut Order<I, Q>) {
//     let timestampMicroSeconds = timestamp::now_microseconds();
//
//     let side = order.metadata.side;
//     let priceVal = fixed_point_64::value(order.metadata.price);
//
//     let finalizeEventHandle = &mut book.finalizeEvents;
//     let executionEventHandle = &mut book.executionEvents;
//     let quoteDecimals = book.qDecimals;
//     let orderMap = &mut book.orderMap;
//     let finalizedOrderMap = &mut book.finalizedOrderMap;
//     let sellTree = &mut book.sells;
//     let buyTree = &mut book.buys;
//
//     // Move side comparison outside of the match loop to save on gas costs.
//     if (side == SIDE_BUY) {
//         let minAskKey = min_key(sellTree);
//
//         while (!is_empty(sellTree) && minAskKey <= priceVal) {
//             let bookOrderID = *first_value_at(sellTree, minAskKey);
//             let bookOrder = table::borrow_mut(orderMap, bookOrderID);
//             let (price, executedQty, orderFinalized, bookOrderFinalized) = execute_orders(
//                 order,
//                 bookOrder,
//                 quoteDecimals,
//                 timestampMicroSeconds,
//                 finalizeEventHandle,
//                 executionEventHandle,
//             );
//
//             // Settle funds.
//             swap_collateral(order, bookOrder, price, executedQty);
//
//             if (bookOrderFinalized) {
//                 let bookOrder = table::remove(orderMap, bookOrderID);
//                 settle_unsettled_collateral(&mut bookOrder);
//                 table::add(finalizedOrderMap, bookOrder.id, bookOrder);
//                 order_store::delete_value(sellTree, minAskKey, bookOrderID);
//             };
//
//             if (orderFinalized) {
//                 break
//             };
//
//             minAskKey = min_key(sellTree);
//         }
//     } else if (side == SIDE_SELL) {
//         let maxBidKey = max_key(buyTree);
//
//         while (!is_empty(buyTree) && maxBidKey >= priceVal) {
//             let bookOrderID = *first_value_at(buyTree, maxBidKey);
//             let bookOrder = table::borrow_mut(orderMap, bookOrderID);
//             let (price, executedQty, orderFinalized, bookOrderFinalized) = execute_orders(
//                 order,
//                 bookOrder,
//                 quoteDecimals,
//                 timestampMicroSeconds,
//                 finalizeEventHandle,
//                 executionEventHandle,
//             );
//
//             // Settle funds.
//             swap_collateral(bookOrder, order, price, executedQty);
//
//             if (bookOrderFinalized) {
//                 let bookOrder = table::remove(orderMap, bookOrderID);
//                 settle_unsettled_collateral(&mut bookOrder);
//                 table::add(finalizedOrderMap, bookOrder.id, bookOrder);
//                 order_store::delete_value(buyTree, maxBidKey, bookOrderID);
//             };
//
//             if (orderFinalized) {
//                 break
//             };
//
//             maxBidKey = max_key(buyTree);
//         }
//     };
// }
//
// fun execute_orders<I, Q>(
//     order: &mut Order<I, Q>,
//     bookOrder: &mut Order<I, Q>,
//     quoteDecimals: u8,
//     timestampMicroSeconds: u64,
//     finalizeEvents: &mut EventHandle<FinalizeEvent>,
//     executionEvents: &mut EventHandle<ExecutionEvent>,
// ): (FixedPoint64, FixedPoint64, bool, bool) {
//     let orderRemainingQty = order.metadata.remainingQty;
//     let orderPrice = order.metadata.price;
//
//     let bookOrderRemainingQty = bookOrder.metadata.remainingQty;
//     let bookOrderPrice = bookOrder.metadata.price;
//
//     // Shouldn't need to worry about over executing collateral because the minAsk price is less than the
//     // maxBid price.
//     let executedQty = fixed_point_64::min(orderRemainingQty, bookOrderRemainingQty);
//
//     order.metadata.updateCounter = order.metadata.updateCounter + 1;
//     order.metadata.executionCounter = order.metadata.executionCounter + 1;
//     order.metadata.remainingQty = fixed_point_64::sub(order.metadata.remainingQty, executedQty);
//
//     bookOrder.metadata.updateCounter = bookOrder.metadata.updateCounter + 1;
//     bookOrder.metadata.executionCounter = bookOrder.metadata.executionCounter + 1;
//     bookOrder.metadata.remainingQty = fixed_point_64::sub(bookOrder.metadata.remainingQty, executedQty);
//
//     // Give the midpoint for the price.
//     // TODO: compute fees using market fee structure.
//     let price = fixed_point_64::divide_round_up(
//         fixed_point_64::add(orderPrice, bookOrderPrice),
//         from_u64(2, 0),
//     );
//     // Its possible for the midpoint to have more decimal places than the market allows for quotes.
//     // In this case, round up.
//     price = fixed_point_64::round_up_to_decimals(price, quoteDecimals);
//
//     // Update status of orders.
//     let orderFinalized = finalize_order_if_needed(finalizeEvents, order);
//     let orderMetadata = order.metadata;
//     let bookOrderFinalized = finalize_order_if_needed(finalizeEvents, bookOrder);
//     let bookOrderMetadata = bookOrder.metadata;
//
//     // Emit execution events after having modified what we need to.
//     emit_event(executionEvents, ExecutionEvent {
//         orderID: order.id,
//         orderMetadata,
//         oppositeOrderID: bookOrder.id,
//         oppositeOrderMetadata: bookOrderMetadata,
//         price,
//         qty: executedQty,
//         timestampMicroSeconds,
//     });
//     emit_event(executionEvents, ExecutionEvent {
//         orderID: bookOrder.id,
//         orderMetadata: bookOrderMetadata,
//         oppositeOrderID: order.id,
//         oppositeOrderMetadata: orderMetadata,
//         price,
//         qty: executedQty,
//         timestampMicroSeconds,
//     });
//
//     (price, executedQty, orderFinalized, bookOrderFinalized)
// }
//
// fun get_quote<I, Q>(book: &OrderBook<I, Q>): Quote {
//     let timestamp = timestamp::now_microseconds();
//
//     let zero = fixed_point_64::zero();
//     let bidSize = zero;
//     let askSize = zero;
//     let minAsk = zero;
//     let maxBid = zero;
//
//     if (!is_empty(&book.buys)) {
//         maxBid = fixed_point_64::new_u128(max_key(&book.buys));
//         bidSize = get_size(&book.orderMap, &book.buys, maxBid);
//     };
//
//     if (!is_empty(&book.sells)) {
//         minAsk = fixed_point_64::new_u128(min_key(&book.sells));
//         askSize = get_size(&book.orderMap, &book.sells, minAsk);
//     };
//
//     Quote {
//         instrumentType: type_info::type_of<I>(),
//         quoteType: type_info::type_of<Q>(),
//         minAsk,
//         askSize,
//         maxBid,
//         bidSize,
//         timestampMicroSeconds: timestamp,
//     }
// }
//
// fun get_size<I, Q>(
//     orderMap: &table::Table<OrderID, Order<I, Q>>,
//     orderTree: &Tree<OrderID>,
//     price: FixedPoint64,
// ): FixedPoint64 {
//     let sum = fixed_point_64::zero();
//     let ordersList = order_store::values_at_list(orderTree, fixed_point_64::value(price));
//     let ordersListIterator = linked_list::iterator(ordersList);
//     while (linked_list::has_next(&ordersListIterator)) {
//         let orderID = linked_list::get_next(ordersList,&mut ordersListIterator);
//         let order = table::borrow(orderMap, orderID);
//         sum = fixed_point_64::add(sum, order.metadata.remainingQty);
//     };
//     sum
// }
//
// //
// // Validation functions.
// //
//
// fun validate_order<I, Q>(order: &Order<I, Q>) {
//     let metadata = &order.metadata;
//     let type = metadata.type;
//     // TODO: add support for FOK and POST orders.
//     assert!(type == TYPE_IOC || type == TYPE_RESTING, ERR_INVALID_TYPE);
//     assert!(metadata.side == SIDE_BUY || metadata.side == SIDE_SELL, ERR_INVALID_SIDE);
//     assert!(string::length(&metadata.clientOrderID) < 40, ERR_CLORDID_TOO_LARGE);
// }
//

//
// //
// // Order specific helpers.
// //
//
// fun finalize_order_if_needed<I, Q>(
//     finalize_event_handle: &mut EventHandle<FinalizeEvent>,
//     order: &mut Order<I, Q>,
// ): bool {
//     if (!has_remaining_qty(order)) {
//         order.metadata.status = STATUS_FILLED;
//         order.metadata.updateCounter = order.metadata.updateCounter + 1;
//         emit_event(finalize_event_handle, FinalizeEvent{
//             orderID: order.id,
//             orderMetadata: order.metadata,
//             cancelAgent: CANCEL_AGENT_NONE,
//
//             timestampMicroSeconds: timestamp::now_microseconds(),
//         });
//         return true
//     };
//     false
// }
//
// fun emit_order_created_event<I, Q>(book: &mut OrderBook<I, Q>, order: &Order<I, Q>) {
//     emit_event(&mut book.createOrderEvents, CreateEvent{
//         orderID: order.id,
//         orderMetadata: order.metadata,
//         timestampMicroSeconds: timestamp::now_microseconds(),
//     });
// }
//
// fun has_remaining_qty<I, Q>(order: &Order<I, Q>): bool {
//     !fixed_point_64::eq(order.metadata.remainingQty, fixed_point_64::zero())
// }
//
// fun get_remaining_collateral<I, Q>(order: &Order<I, Q>): FixedPoint64 {
//     if (order.metadata.side == SIDE_BUY) {
//         let coinDecimals = coin::decimals<Q>();
//         from_u64(coin::value(&order.buyCollateral), coinDecimals)
//     } else {
//         let coinDecimals = coin::decimals<I>();
//         from_u64(coin::value(&order.sellCollateral), coinDecimals)
//     }
// }
//
// fun mark_cancelled_order<I, Q>(
//     finalize_event_handle: &mut EventHandle<FinalizeEvent>,
//     order: &mut Order<I, Q>,
//     cancelAgent: u8,
// ) {
//     order.metadata.status = STATUS_CANCELLED;
//     order.metadata.updateCounter = order.metadata.updateCounter + 1;
//     emit_event(finalize_event_handle, FinalizeEvent{
//         orderID: order.id,
//         orderMetadata: order.metadata,
//         cancelAgent,
//         timestampMicroSeconds: timestamp::now_microseconds(),
//     })
// }
//
// fun is_order_finalized<I, Q>(order: &Order<I, Q>): bool {
//     order.metadata.status == STATUS_FILLED ||
//     order.metadata.status == STATUS_CANCELLED
// }
//
// //
// // Collateral functions.
// //
//
// fun obtain_order_collateral<I, Q>(
//     owner: &signer,
//     side: u8,
//     price: FixedPoint64,
//     qty: FixedPoint64,
// ): (coin::Coin<Q>, coin::Coin<I>) {
//     if (side == SIDE_BUY) {
//         (
//             coin::withdraw<Q>(
//                 owner,
//                 fixed_point_64::to_u64(fixed_point_64::multiply_round_up(price, qty), coin::decimals<Q>()),
//             ),
//             coin::zero<I>(),
//         )
//     } else {
//         (
//             coin::zero<Q>(),
//             coin::withdraw<I>(
//                 owner,
//                 fixed_point_64::to_u64(qty, coin::decimals<I>()),
//             ),
//         )
//     }
// }
//
// fun settle_unsettled_collateral<I, Q>(order: &mut Order<I, Q>) {
//     let orderOwner = order.id.owner;
//
//     let buyCollateral = coin::extract_all(&mut order.buyCollateral);
//     let sellCollateral = coin::extract_all(&mut order.sellCollateral);
//
//     // Return any remaining collateral to user.
//     coin::deposit(orderOwner, buyCollateral);
//     coin::deposit(orderOwner, sellCollateral);
// }
//
// fun swap_collateral<I, Q>(
//     buy: &mut Order<I, Q>,
//     sell: &mut Order<I, Q>,
//     price: FixedPoint64,
//     qty: FixedPoint64,
// ) {
//     let buyCollateral = extract_buy_collateral(buy, price, qty);
//     coin::deposit(sell.id.owner, buyCollateral);
//     let sellCollateral = extract_sell_collateral(sell, qty);
//     coin::deposit(buy.id.owner, sellCollateral);
// }
//
// fun extract_buy_collateral<I, Q>(order: &mut Order<I, Q>, price: FixedPoint64, qty: FixedPoint64): coin::Coin<Q> {
//     let collateralUsed = fixed_point_64::multiply_trunc(price, qty);
//     let coinDecimals = coin::decimals<Q>();
//     let amt = fixed_point_64::to_u64(collateralUsed, coinDecimals);
//     coin::extract(&mut order.buyCollateral, amt)
// }
//
// fun extract_sell_collateral<I, Q>(order: &mut Order<I, Q>, qty: FixedPoint64): coin::Coin<I> {
//     let coinDecimals = coin::decimals<I>();
//     let amt = fixed_point_64::to_u64(qty, coinDecimals);
//     coin::extract(&mut order.sellCollateral, amt)
// }
//
// fun create_user_info_if_needed<I, Q>(owner: &signer) {
//     if (exists<UserMarketInfo<I, Q>>(address_of(owner))) {
//         return
//     };
//     move_to(owner, UserMarketInfo<I, Q> {
//         idCounter: 0,
//     });
// }
//
// #[test(owner = @ferum, user = @0x2)]
// #[expected_failure(abort_code = 400)]
// fun test_init_duplicate_market(owner: &signer, user: &signer) {
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     init_ferum(owner, 0, 0, 0, 0);
//     setup_fake_coins(owner, user, 100, 8);
//     init_market_entry<FMA, FMB>(owner, 4, 4);
//     init_market_entry<FMA, FMB>(owner, 4, 4);
// }
//
// #[test(owner = @ferum, user = @0x2)]
// #[expected_failure(abort_code = 201)]
// fun test_add_resting_order_to_uninited_book(owner: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that a limit order added for uninitialized book fails.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     init_ferum(owner, 0, 0, 0, 0);
//     setup_fake_coins(owner, user, 100, 8);
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 1, 1, empty_client_order_id());
// }
//
// #[test(owner = @ferum, user = @0x2)]
// #[expected_failure(abort_code = 201)]
// fun test_add_ioc_order_to_uninited_book(owner: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that a limit order added for uninitialized book fails.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     init_ferum(owner, 0, 0, 0, 0);
//     setup_fake_coins(owner, user, 100, 18);
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_IOC, 1, 1, empty_client_order_id());
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2)]
// #[expected_failure]
// fun test_add_buy_order_exceed_balance(owner: &signer, aptos: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that a buy order that requires more collateral than the user has fails
//     // (because of order quantity).
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8); // Users have 100 FMA and FMB.
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // BUY 120 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 1200000, empty_client_order_id());
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2)]
// #[expected_failure]
// fun test_add_buy_order_exceed_balance_price(owner: &signer, aptos: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that a buy order that requires more collateral than the user has fails.
//     // (because of order price).
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8); // Users have 100 FMA and FMB.
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // BUY 1 FMA @ 120 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 1200000, 10000, empty_client_order_id());
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2)]
// #[expected_failure]
// fun test_add_sell_order_exceed_balance(owner: &signer, aptos: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that a sell order that requires more collateral than the user has fails.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8); // Users have 100 FMA and FMB.
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // SELL 120 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 10000, 1200000, empty_client_order_id());
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2)]
// fun test_add_sell_order_no_precision_loss(owner: &signer, aptos: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that a sell order placed with the minimum qty doesn't fail.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8); // Users have 100 FMA and FMB.
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // SELL 0.00000001 FMA @ 0.00000001 FMB
//     // Requires obtaining 0.00000001 FMA of collateral, which is possible.
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 1, 1, empty_client_order_id());
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2)]
// fun test_add_orders_to_empty_book(owner: &signer, aptos: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that orders can be added to empty book and none of them trigger.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 20000, 10000, empty_client_order_id()); // BUY 1 FMA @ 2 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 100000, 10000, empty_client_order_id()); // BUY 1 FMA @ 10 FMB
//
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 200000, 100000, empty_client_order_id()); // SELL 10 FMA @ 20 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id()); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id()); // SELL 1 FMA @ 25 FMB
//
//     assert!(coin::balance<FMA>(address_of(owner)) == 8800000000, 0);
//     assert!(coin::balance<FMB>(address_of(owner)) == 7800000000, 0);
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2)]
// fun test_cancel_orders(owner: &signer, aptos: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that orders can be added a book and then cancelled.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // BUY 10 FMA @ 1 FMB
//     let buyID = add_order<FMA, FMB>(
//         user,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(10000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//     // SELL 10 FMA @ 20 FMB
//     let sellID = add_order<FMA, FMB>(
//         user,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(200000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//
//     cancel_order_entry<FMA, FMB>(user, buyID.counter);
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, buyID, STATUS_CANCELLED);
//     };
//
//     cancel_order_entry<FMA, FMB>(user, sellID.counter);
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, sellID, STATUS_CANCELLED);
//     };
//
//     assert!(coin::balance<FMB>(address_of(user)) == 10000000000, 0);
//     assert!(coin::balance<FMA>(address_of(user)) == 10000000000, 0);
// }
//
// #[test(
//     owner = @ferum,
//     aptos = @0x1,
//     user1 = @0x2,
//     user2 = @0x3,
//     protocol1 = @0x4,
//     protocol2 = @0x5,
//     user1Protocol1Account = @0x6,
//     user1Protocol2Account = @0x7,
//     user2Protocol1Account = @0x8,
//     user2Protocol2Account = @0x9,
// )]
// fun test_cancel_all_orders_for_user(
//     owner: &signer,
//     aptos: &signer,
//     user1: &signer,
//     user2: &signer,
//     protocol1: &signer,
//     protocol2: &signer,
//     user1Protocol1Account: &signer,
//     user1Protocol2Account: &signer,
//     user2Protocol1Account: &signer,
//     user2Protocol2Account: &signer,
// ) acquires OrderBook, UserMarketInfo {
//     // Tests that cancel_all_orders_for_user only cancels orders for the user only
//     // for the requesting protocol.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     account::create_account_for_test(address_of(protocol1));
//     account::create_account_for_test(address_of(protocol2));
//     account::create_account_for_test(address_of(user1Protocol1Account));
//     account::create_account_for_test(address_of(user1Protocol2Account));
//     account::create_account_for_test(address_of(user2Protocol1Account));
//     account::create_account_for_test(address_of(user2Protocol2Account));
//     setup_fake_coins(owner, user1, 10000000000, 8);
//     register_fma_fmb(owner, user2, 10000000000);
//     register_fma_fmb(owner, user1Protocol1Account, 10000000000);
//     register_fma_fmb(owner, user1Protocol2Account, 10000000000);
//     register_fma_fmb(owner, user2Protocol1Account, 10000000000);
//     register_fma_fmb(owner, user2Protocol2Account, 10000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     let capProtocol1 = register_protocol(protocol1);
//     let capProtocol2 = register_protocol(protocol2);
//     let user1IdentifierProtocol1 = get_user_identifier(user1, &capProtocol1);
//     let user1IdentifierProtocol2 = get_user_identifier(user1, &capProtocol2);
//     let user2IdentifierProtocol1 = get_user_identifier(user2, &capProtocol1);
//     let user2IdentifierProtocol2 = get_user_identifier(user2, &capProtocol2);
//
//     let cancelledOrder1ID = add_order_for_user<FMA, FMB>(
//         user1Protocol1Account,
//         user1IdentifierProtocol1,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(10000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     let cancelledOrder2ID = add_order_for_user<FMA, FMB>(
//         user1Protocol1Account,
//         user1IdentifierProtocol1,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(20000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     // An order placed by the user via another protocol.
//     let notCancelledOrder1 = add_order_for_user<FMA, FMB>(
//         user1Protocol2Account,
//         user1IdentifierProtocol2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(20000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     // An order placed by another user via the same protocol.
//     let notCancelledOrder2 = add_order_for_user<FMA, FMB>(
//         user2Protocol1Account,
//         user2IdentifierProtocol1,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(20000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     // An order placed by another user on another protocol.
//     let notCancelledOrder3 = add_order_for_user<FMA, FMB>(
//         user2Protocol2Account,
//         user2IdentifierProtocol2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(20000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     // An order placed by the user directly.
//     let notCancelledOrder4 = add_order<FMA, FMB>(
//         user1,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(20000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     // An order placed by another user directly.
//     let notCancelledOrder5 = add_order<FMA, FMB>(
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(20000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     let cancelledOrders = vector<OrderID>[cancelledOrder1ID, cancelledOrder2ID];
//     let uncancelledOrders = vector<OrderID>[
//         notCancelledOrder1,
//         notCancelledOrder2,
//         notCancelledOrder3,
//         notCancelledOrder4,
//         notCancelledOrder5,
//     ];
//
//     cancel_all_orders_for_owner_entry<FMA, FMB>(user1Protocol1Account);
//
//     let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//
//     let i = 0;
//     let vecLength = vector::length(&cancelledOrders);
//     while (i < vecLength) {
//         let orderID = vector::pop_back(&mut cancelledOrders);
//         assert_order_finalized(book, orderID, STATUS_CANCELLED);
//         i = i + 1;
//     };
//     vector::destroy_empty(cancelledOrders);
//
//     i = 0;
//     vecLength = vector::length(&uncancelledOrders);
//     while (i < vecLength) {
//         let orderID = vector::pop_back(&mut uncancelledOrders);
//         let order = get_order(book, orderID);
//         assert!(!is_order_finalized(order), 0);
//         i = i + 1;
//     };
//     vector::destroy_empty(uncancelledOrders);
//
//     drop_protocol_capability(capProtocol1);
//     drop_protocol_capability(capProtocol2);
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2, userProtocolAccount = @0x3, protocol = @0x4)]
// fun test_cancel_order_for_user_made_using_protocol_user_account(
//     owner: &signer,
//     aptos: &signer,
//     user: &signer,
//     userProtocolAccount: &signer,
//     protocol: &signer,
// ) acquires OrderBook, UserMarketInfo {
//     // Tests that protocol created order can be added a book and then cancelled.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     account::create_account_for_test(address_of(userProtocolAccount));
//     setup_fake_coins(owner, userProtocolAccount, 10000000000, 8);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     let cap = register_protocol(protocol);
//
//     // BUY 10 FMA @ 1 FMB
//     let userIdentifier = get_user_identifier(user, &cap);
//     let buyID = add_order_for_user<FMA, FMB>(
//         userProtocolAccount,
//         userIdentifier,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(10000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//
//     cancel_order_for_user<FMA, FMB>(protocol, userIdentifier, address_of(userProtocolAccount), buyID.counter);
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, buyID, STATUS_CANCELLED);
//     };
//
//     assert!(coin::balance<FMB>(address_of(userProtocolAccount)) == 10000000000, 0);
//     assert!(coin::balance<FMA>(address_of(userProtocolAccount)) == 10000000000, 0);
//
//     drop_protocol_capability(cap);
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2, protocol = @0x4)]
// fun test_cancel_order_for_user_made_using_user_account_directly(
//     owner: &signer,
//     aptos: &signer,
//     user: &signer,
//     protocol: &signer,
// ) acquires OrderBook, UserMarketInfo {
//     // Tests that protocol created order can be added a book and then cancelled.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     let cap = register_protocol(protocol);
//
//     // BUY 10 FMA @ 1 FMB
//     let userIdentifier = get_user_identifier(user, &cap);
//     let buyID = add_order_for_user<FMA, FMB>(
//         user,
//         userIdentifier,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(10000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//
//     cancel_order_for_user<FMA, FMB>(protocol, userIdentifier, address_of(user), buyID.counter);
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, buyID, STATUS_CANCELLED);
//     };
//
//     assert!(coin::balance<FMB>(address_of(user)) == 10000000000, 0);
//     assert!(coin::balance<FMA>(address_of(user)) == 10000000000, 0);
//
//     drop_protocol_capability(cap);
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2, protocol = @0x4)]
// #[expected_failure(abort_code = 410)]
// fun test_cancel_order_for_user_without_protocol_capability(
//     owner: &signer,
//     aptos: &signer,
//     user: &signer,
//     protocol: &signer,
// ) acquires OrderBook, UserMarketInfo {
//     // Tests that custodial orders can't be cancelled by the user.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     let cap = register_protocol(protocol);
//
//     // BUY 10 FMA @ 1 FMB
//     let userIdentifier = get_user_identifier(user, &cap);
//     let buyID = add_order_for_user<FMA, FMB>(
//         user,
//         userIdentifier,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(10000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//
//     cancel_order_entry<FMA, FMB>(user,  buyID.counter);
//
//     drop_protocol_capability(cap);
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2, protocol = @0x4)]
// #[expected_failure(abort_code = 404)]
// fun test_cancel_non_protocol_order_as_protocol(
//     owner: &signer,
//     aptos: &signer,
//     user: &signer,
//     protocol: &signer,
// ) acquires OrderBook, UserMarketInfo {
//     // Tests that non custodial orders can only be cancelled by the original user.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     let cap = register_protocol(protocol);
//
//     // BUY 10 FMA @ 1 FMB
//     let buyID = add_order<FMA, FMB>(
//         user,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(10000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//
//     let userIdentifier = get_user_identifier(user, &cap);
//     cancel_order_for_user<FMA, FMB>(protocol, userIdentifier, address_of(user), buyID.counter);
//
//     drop_protocol_capability(cap);
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x4)]
// #[expected_failure]
// fun test_cancel_order_wrong_user(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that non custodial orders can only be cancelled by the original user.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     setup_fake_coins(owner, user1, 10000000000, 8);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // BUY 10 FMA @ 1 FMB
//     let buyID = add_order<FMA, FMB>(
//         user1,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(10000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//
//     cancel_order_entry<FMA, FMB>(user2, buyID.counter);
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2)]
// fun test_add_ioc_orders_cancelled(owner: &signer, aptos: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that IOC orders should get cancelled because there is nothing to execute them against.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // BUY 1 FMA @ 10 FMB
//     {
//         let orderID = add_order<FMA, FMB>(
//             owner,
//             SIDE_BUY,
//             TYPE_IOC,
//             from_u64(100000, 4),
//             from_u64(10000, 4),
//             empty_client_order_id(),
//         );
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_CANCELLED);
//     };
//
//     // SELL 1 FMA @ 10 FMB.
//     {
//         let orderID = add_order<FMA, FMB>(
//             owner,
//             SIDE_SELL,
//             TYPE_IOC,
//             from_u64(100000, 4),
//             from_u64(10000, 4),
//             empty_client_order_id(),
//         );
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_CANCELLED);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user = @0x2)]
// fun test_swap(owner: &signer, aptos: &signer, user: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that a swap mimics placing an IOC order.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user));
//     setup_fake_coins(owner, user, 10000000000, 8);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Swap 1 FMA for a max price 10 FMB.
//     {
//         let orderID = swap<FMA, FMB>(
//             owner,
//             SIDE_BUY,
//             from_u64(100000, 4),
//             from_u64(10000, 4),
//             empty_client_order_id(),
//         );
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_CANCELLED);
//         let order = get_order(book, orderID);
//         assert!(order.metadata.type == TYPE_IOC, 0)
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_ioc_buy_execute_against_limit(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that IOC buy order execute against limit orders.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 10000000000, 8);
//     register_fma(owner, user2, 10000000000);
//     register_fmb(owner, user2, 10000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 20000, 10000, empty_client_order_id()); // BUY 1 FMA @ 2 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 100000, 10000, empty_client_order_id()); // BUY 1 FMA @ 10 FMB
//
//     let targetSellID = add_order<FMA, FMB>(  // SELL 10 FMA @ 20 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(200000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id(), ); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id(), );  // SELL 1 FMA @ 25 FMB
//
//     // BUY 1 FMA @ 20 FMB.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_BUY,
//         TYPE_IOC,
//         from_u64(200000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify IOC order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 8000000000, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 10100000000, 0);
//     };
//
//     // Verify limit order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         let order = get_order<FMA, FMB>(book, targetSellID);
//         assert!(order.metadata.status == STATUS_PENDING, 0);
//         assert!(coin::value(&order.buyCollateral) == 0, 0);
//         assert!(coin::value(&order.sellCollateral) == 900000000, 0);
//         assert!(coin::balance<FMB>(address_of(user2)) == 12000000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 9000000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_limit_buy_execute_fully_against_limit(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that limit buy order executes completely against limit sell order.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 20000000000, 8);
//     register_fma(owner, user2, 20000000000);
//     register_fmb(owner, user2, 20000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 20000, 10000, empty_client_order_id()); // BUY 1 FMA @ 2 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 100000, 10000, empty_client_order_id()); // BUY 1 FMA @ 10 FMB
//
//     let targetSellID = add_order<FMA, FMB>( // SELL 10 FMA @ 20 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(200000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id()); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id()); // SELL 1 FMA @ 25 FMB
//
//     // BUY 10 FMA at 20 FMB.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(200000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify user1.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 0, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 21000000000, 0);
//     };
//
//     // Verify user2.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, targetSellID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user2)) == 40000000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 19000000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_ioc_buy_execute_fully_against_limit(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that IOC buy order executes completely against limit sell order.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 20000000000, 8);
//     register_fma(owner, user2, 20000000000);
//     register_fmb(owner, user2, 20000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 20000, 10000, empty_client_order_id()); // BUY 1 FMA @ 2 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 100000, 10000, empty_client_order_id()); // BUY 1 FMA @ 10 FMB
//
//     let targetSellID = add_order<FMA, FMB>(  // SELL 10 FMA @ 20 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(200000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id()); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id()); // SELL 1 FMA @ 25 FMB
//
//     // BUY 10 FMA @ 20 FMB.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_BUY,
//         TYPE_IOC,
//         from_u64(200000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify IOC order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 0, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 21000000000, 0);
//     };
//
//     // Verify limit order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, targetSellID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user2)) == 40000000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 19000000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_ioc_sell_execute_against_limit(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that market IOC order execute against limit orders.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 10000000000, 8);
//     register_fma(owner, user2, 10000000000);
//     register_fmb(owner, user2, 10000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 20000, 10000, empty_client_order_id()); // BUY 1 FMA @ 2 FMB
//     let targetBuyID = add_order<FMA, FMB>( // BUY 1 FMA @ 10 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(100000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 200000,100000,empty_client_order_id());  // SELL 10 FMA @ 20 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id()); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id()); // SELL 1 FMA @ 25 FMB
//
//     // SELL 1 FMA @ 5 FMB.
//     // Order executes for ((5 + 10) / 2) = 7.5 FMB.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_SELL,
//         TYPE_IOC,
//         from_u64(50000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify IOC order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 10750000000, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 9900000000, 0);
//     };
//
//     // Verify limit order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, targetBuyID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user2)) == 9250000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 10100000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_ioc_sell_execute_against_multiple_limits(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that market IOC order execute against multiple limit orders.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 10000000000, 8);
//     register_fma(owner, user2, 10000000000);
//     register_fmb(owner, user2, 10000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     let targetBuyIDC = add_order<FMA, FMB>( // BUY 10 FMA @ 1 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(10000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//     let targetBuyIDB = add_order<FMA, FMB>( // BUY 1 FMA @ 2 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(20000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     let targetBuyIDA = add_order<FMA, FMB>( // BUY 1 FMA @ 10 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(100000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 200000, 100000, empty_client_order_id());  // SELL 10 FMA @ 20 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id()); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id()); // SELL 1 FMA @ 25 FMB
//
//     // SELL 5 FMA @ 1 FMB.
//     // Order's first execution is for 1 FMA for ((1 + 10) / 2) = 5.5 FMB.
//     // Order's second execution is for 1 FMA for ((1 + 2) / 2) = 1.5 FMB.
//     // Order's third execution is for 3 FMA for ((1 + 1) / 2) = 1 FMB.
//     // User should receive 10 FMB total.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_SELL,
//         TYPE_IOC,
//         from_u64(10000, 4),
//         from_u64(50000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify IOC order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//
//         assert_order_finalized(book, orderID, STATUS_FILLED);
//
//         assert!(coin::balance<FMB>(address_of(user1)) == 11000000000, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 9500000000, 0);
//     };
//
//     // Verify limit order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//
//         assert_order_finalized(book, targetBuyIDA, STATUS_FILLED);
//         assert_order_finalized(book, targetBuyIDB, STATUS_FILLED);
//
//         let orderC = get_order<FMA, FMB>(book, targetBuyIDC);
//         assert!(orderC.metadata.status == STATUS_PENDING, 0);
//         assert!(coin::value(&orderC.buyCollateral) == 700000000, 0);
//         assert!(coin::value(&orderC.sellCollateral) == 0, 0);
//
//         assert!(coin::balance<FMB>(address_of(user2)) == 8300000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 10500000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_ioc_buy_execute_against_multiple_limits(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that IOC buy order execute against multiple limit orders.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 50000000000, 8);
//     register_fma(owner, user2, 50000000000);
//     register_fmb(owner, user2, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 20000, 10000, empty_client_order_id()); // BUY 1 FMA @ 2 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 100000, 10000, empty_client_order_id()); // BUY 1 FMA @ 10 FMB
//
//     let targetSellIDA = add_order<FMA, FMB>(  // SELL 10 FMA @ 20 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(200000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//     let targetSellIDB = add_order<FMA, FMB>( // SELL 1 FMA @ 21 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(210000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     let targetSellIDC = add_order<FMA, FMB>( // SELL 1 FMA @ 25 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(250000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     // BUY 12 FMA @ 30 FMB.
//     // Order's first execution is for 10 FMA for ((30 + 20) / 2) = 25 FMB.
//     // Order's second execution is for 1 FMA for ((30 + 21) / 2) = 25.5 FMB.
//     // Order's third execution is for 1 FMA for ((30 + 25) / 2) = 27.5 FMB.
//     // User should spend 303 FMB total.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_BUY,
//         TYPE_IOC,
//         from_u64(300000, 4),
//         from_u64(120000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify IOC order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 19700000000, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 51200000000, 0);
//     };
//
//     // Verify limit order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//
//         assert_order_finalized(book, targetSellIDA, STATUS_FILLED);
//         assert_order_finalized(book, targetSellIDB, STATUS_FILLED);
//         assert_order_finalized(book, targetSellIDC, STATUS_FILLED);
//
//         assert!(coin::balance<FMB>(address_of(user2)) == 80300000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 48800000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_ioc_sell_eat_book_not_filled(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that market IOC order that eats through the book is cancelled.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 50000000000, 8);
//     register_fma(owner, user2, 50000000000);
//     register_fmb(owner, user2, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     let targetBuyIDA = add_order<FMA, FMB>( // BUY 1 FMA @ 10 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(100000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 200000, 100000, empty_client_order_id());  // SELL 10 FMA @ 20 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id()); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id()); // SELL 1 FMA @ 25 FMB
//
//     // SELL 2 FMA @ 1 FMB.
//     // Order's first execution is for 1 FMA for ((1 + 10) / 2) = 5.5 FMB.
//     // User should receive 5.5 FMB total.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_SELL,
//         TYPE_IOC,
//         from_u64(10000, 4),
//         from_u64(20000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify IOC order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_CANCELLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 50550000000, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 49900000000, 0);
//     };
//
//     // Verify limit order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//
//         assert_order_finalized(book, targetBuyIDA, STATUS_FILLED);
//
//         assert!(coin::balance<FMB>(address_of(user2)) == 49450000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 50100000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_ioc_buy_eat_book_not_filled(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that IOC buy order that eats through the book is cancelled.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 50000000000, 8);
//     register_fma(owner, user2, 50000000000);
//     register_fmb(owner, user2, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 20000, 10000, empty_client_order_id()); // BUY 1 FMA @ 2 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 100000, 10000, empty_client_order_id()); // BUY 1 FMA @ 10 FMB
//
//     let targetSellIDA = add_order<FMA, FMB>( // SELL 1 FMA @ 25 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(250000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     // BUY 2 FMA @ 120 FMB.
//     // Order's first execution is for 1 FMA for ((120 + 25) / 2) = 72.5 FMB.
//     // User should spend 72.5 FMB total.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_BUY,
//         TYPE_IOC,
//         from_u64(1200000, 4),
//         from_u64(20000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify IOC order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_CANCELLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 42750000000, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 50100000000, 0);
//     };
//
//     // Verify limit order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//
//         assert_order_finalized(book, targetSellIDA, STATUS_FILLED);
//
//         assert!(coin::balance<FMB>(address_of(user2)) == 57250000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 49900000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_limit_buy_execute(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that limit buy order executes against other limit orders.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 10000000000, 8);
//     register_fma(owner, user2, 10000000000);
//     register_fmb(owner, user2, 10000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 20000, 10000, empty_client_order_id()); // BUY 1 FMA @ 2 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 100000, 10000, empty_client_order_id()); // BUY 1 FMA @ 10 FMB
//
//     let targetSellID = add_order<FMA, FMB>( // SELL 10 FMA @ 20 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(200000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id()); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id()); // SELL 1 FMA @ 25 FMB
//
//     // BUY 1 FMA @ 20 FMB.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(200000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify buy order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 8000000000, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 10100000000, 0);
//     };
//
//     // Verify sell order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         let order = get_order<FMA, FMB>(book, targetSellID);
//         assert!(order.metadata.status == STATUS_PENDING, 0);
//         assert!(coin::value(&order.buyCollateral) == 0, 0);
//         assert!(coin::value(&order.sellCollateral) == 900000000, 0);
//         assert!(coin::balance<FMB>(address_of(user2)) == 12000000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 9000000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_limit_sell_execute(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that limit sell order executes against other limit orders.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 10000000000, 8);
//     register_fma(owner, user2, 10000000000);
//     register_fmb(owner, user2, 10000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 95000, 10000, empty_client_order_id()); // BUY 1 FMA @ 9.5 FMB
//     let targetBuyID = add_order<FMA, FMB>( // BUY 1 FMA @ 10 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(100000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 200000, 100000, empty_client_order_id()); // SELL 10 FMA @ 20 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id()); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id()); // SELL 1 FMA @ 25 FMB
//
//     // SELL 1 FMA @ 9 FMB.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(90000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify sell order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_FILLED);
//         assert!(coin::balance<FMA>(address_of(user1)) == 9900000000, 0);
//         assert!(coin::balance<FMB>(address_of(user1)) == 10950000000, 0);
//     };
//
//     // Verify buy order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, targetBuyID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user2)) == 9050000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 10100000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_limit_buy_execute_multiple(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that limit buy order executes against multiple other limit orders.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 50000000000, 8);
//     register_fma(owner, user2, 50000000000);
//     register_fmb(owner, user2, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 10000, 100000, empty_client_order_id()); // BUY 10 FMA @ 1 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 20000, 10000, empty_client_order_id()); // BUY 1 FMA @ 2 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 100000, 10000, empty_client_order_id()); // BUY 1 FMA @ 10 FMB
//
//     let targetSellIDA = add_order<FMA, FMB>( // SELL 10 FMA @ 20 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(200000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//     let targetSellIDB = add_order<FMA, FMB>( // SELL 1 FMA @ 21 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(210000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     let targetSellIDC = add_order<FMA, FMB>( // SELL 1 FMA @ 25 FMB
//         user2,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(250000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     // BUY 11 FMA @ 22 FMB.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(220000, 4),
//         from_u64(110000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify buy order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, orderID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 26850000000, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 51100000000, 0);
//     };
//
//     // Verify sell orders' users.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, targetSellIDA, STATUS_FILLED);
//         assert_order_finalized(book, targetSellIDB, STATUS_FILLED);
//
//         let orderC = get_order<FMA, FMB>(book, targetSellIDC);
//         assert!(orderC.metadata.status == STATUS_PENDING, 0);
//         assert!(coin::value(&orderC.buyCollateral) == 0, 0);
//         assert!(coin::value(&orderC.sellCollateral) == 100000000, 0);
//
//         assert!(coin::balance<FMB>(address_of(user2)) == 73150000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 48800000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_limit_sell_execute_multiple(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that limit sell order executes against multiple other limit orders.
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 50000000000, 8);
//     register_fma(owner, user2, 50000000000);
//     register_fmb(owner, user2, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     let targetBuyIDC = add_order<FMA, FMB>( // BUY 10 FMA @ 1 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(10000, 4),
//         from_u64(100000, 4),
//         empty_client_order_id(),
//     );
//     let targetBuyIDB = add_order<FMA, FMB>( // BUY 1 FMA @ 2 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(20000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//     let targetBuyIDA = add_order<FMA, FMB>( // BUY 1 FMA @ 10 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(100000, 4),
//         from_u64(10000, 4),
//         empty_client_order_id(),
//     );
//
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 200000, 100000, empty_client_order_id()); // SELL 10 FMA @ 20 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 210000, 10000, empty_client_order_id()); // SELL 1 FMA @ 21 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 250000, 10000, empty_client_order_id()); // SELL 1 FMA @ 25 FMB
//
//     // SELL 11 FMA @ 1.5 FMB.
//     let orderID = add_order<FMA, FMB>(
//         user1,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(15000, 4),
//         from_u64(110000, 4),
//         empty_client_order_id(),
//     );
//
//     // Verify sell order user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         let order = get_order<FMA, FMB>(book, orderID);
//         assert!(order.metadata.status == STATUS_PENDING, 0);
//         assert!(coin::value(&order.buyCollateral) == 0, 0);
//         assert!(coin::value(&order.sellCollateral) == 900000000, 0);
//         assert!(coin::balance<FMB>(address_of(user1)) == 50750000000, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 48900000000, 0);
//     };
//
//     // Verify buy orders' user.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//
//         assert_order_finalized(book, targetBuyIDA, STATUS_FILLED);
//         assert_order_finalized(book, targetBuyIDB, STATUS_FILLED);
//
//         let orderC = get_order<FMA, FMB>(book, targetBuyIDC);
//         assert!(orderC.metadata.status == STATUS_PENDING, 0);
//         assert!(coin::value(&orderC.buyCollateral) == 1000000000, 0);
//         assert!(coin::value(&orderC.sellCollateral) == 0, 0);
//
//         assert!(coin::balance<FMB>(address_of(user2)) == 48250000000, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 50200000000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1, user1 = @0x2, user2 = @0x3)]
// fun test_limit_orders_precision(owner: &signer, aptos: &signer, user1: &signer, user2: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests that limit order executions that require more precision than the market's instrumentDecimals or
//     // quoteDecimals don't fail (because both parameters are set so that they can be multiplied without exceeding
//     // the underlying coin's decimals).
//
//     account::create_account_for_test(address_of(owner));
//     account::create_account_for_test(address_of(user1));
//     account::create_account_for_test(address_of(user2));
//     setup_fake_coins(owner, user1, 50000000000, 8);
//     register_fma(owner, user2, 50000000000);
//     register_fmb(owner, user2, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     let buyID = add_order<FMA, FMB>( // BUY 0.0002 FMA @ 0.0002 FMB
//         user2,
//         SIDE_BUY,
//         TYPE_RESTING,
//         from_u64(2, 4),
//         from_u64(2, 4),
//         empty_client_order_id(),
//     );
//     let sellID = add_order<FMA, FMB>( // SELL 0.0001 FMA @ 0.0001 FMB
//         user1,
//         SIDE_SELL,
//         TYPE_RESTING,
//         from_u64(1, 4),
//         from_u64(1, 4),
//         empty_client_order_id(),
//     );
//
//     // Note that the midpoint here does exceed the max allowed precision of the underlying quote coin but
//     // we round up:
//     //
//     // price = 0.00015
//     // qty = 0.0001
//     // buy cost = 0.000000015 -> rounded up = 0.00000002
//
//     // Verify buy.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         let order = get_order<FMA, FMB>(book, buyID);
//         assert!(order.metadata.status == STATUS_PENDING, 0);
//         assert!(coin::value(&order.buyCollateral) == 2, 0);
//         assert!(coin::value(&order.sellCollateral) == 0, 0);
//         assert!(coin::balance<FMB>(address_of(user2)) == 49999999996, 0);
//         assert!(coin::balance<FMA>(address_of(user2)) == 50000010000, 0);
//     };
//
//     // Verify sell.
//     {
//         let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//         assert_order_finalized(book, sellID, STATUS_FILLED);
//         assert!(coin::balance<FMB>(address_of(user1)) == 50000000002, 0);
//         assert!(coin::balance<FMA>(address_of(user1)) == 49999990000, 0);
//     };
// }
//
// #[test(owner = @ferum, aptos = @0x1)]
// fun test_quote(owner: &signer, aptos: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests quote is set correctly given an orderbook state.
//
//     account::create_account_for_test(address_of(owner));
//     create_fake_coins(owner, 8);
//     register_fma(owner, owner, 50000000000);
//     register_fmb(owner, owner, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 1, 2, empty_client_order_id()); // BUY 0.0002 FMA @ 0.0001 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 2, 2, empty_client_order_id()); // BUY 0.0002 FMA @ 0.0002 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 2, 2, empty_client_order_id()); // BUY 0.0002 FMA @ 0.0002 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 3, 1, empty_client_order_id()); // SELL 0.0001 FMA @ 0.0003 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 3, 1, empty_client_order_id()); // SELL 0.0001 FMA @ 0.0003 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 4, 1, empty_client_order_id()); // SELL 0.0001 FMA @ 0.0004 FMB
//
//     // Validate quote.
//     let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//     let price = get_quote(book);
//     let expectedPrice = Quote {
//         instrumentType: type_info::type_of<Quote>(),
//         quoteType: type_info::type_of<Quote>(),
//
//         maxBid: fixed_point_64::from_u128(2, 4),
//         bidSize: fixed_point_64::from_u128(4, 4),
//         minAsk: fixed_point_64::from_u128(3, 4),
//         askSize: fixed_point_64::from_u128(2, 4),
//         timestampMicroSeconds: 10,
//     };
//     assert_quote_eq(price, expectedPrice);
// }
//
// #[test(owner = @ferum, aptos = @0x1)]
// fun test_quote_empty_book(owner: &signer, aptos: &signer) acquires OrderBook {
//     // Tests quote is set correctly given an empty orderbook.
//
//     account::create_account_for_test(address_of(owner));
//     create_fake_coins(owner, 8);
//     register_fma(owner, owner, 50000000000);
//     register_fmb(owner, owner, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Validate quote.
//     let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//     let price = get_quote(book);
//     let expectedPrice = Quote {
//         instrumentType: type_info::type_of<Quote>(),
//         quoteType: type_info::type_of<Quote>(),
//         maxBid: fixed_point_64::zero(),
//         bidSize: fixed_point_64::zero(),
//         minAsk: fixed_point_64::zero(),
//         askSize: fixed_point_64::zero(),
//         timestampMicroSeconds: 10,
//     };
//     assert_quote_eq(price, expectedPrice);
// }
//
// #[test(owner = @ferum, aptos = @0x1)]
// fun test_quote_empty_sell_book(owner: &signer, aptos: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests quote is set correctly given an empty sell orderbook.
//
//     account::create_account_for_test(address_of(owner));
//     create_fake_coins(owner, 8);
//     register_fma(owner, owner, 50000000000);
//     register_fmb(owner, owner, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 1, 2, empty_client_order_id()); // BUY 0.0002 FMA @ 0.0001 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 2, 2, empty_client_order_id()); // BUY 0.0002 FMA @ 0.0002 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_BUY, TYPE_RESTING, 2, 2, empty_client_order_id()); // BUY 0.0002 FMA @ 0.0002 FMB
//
//     // Validate quote.
//     let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//     let price = get_quote(book);
//     let expectedPrice = Quote {
//         instrumentType: type_info::type_of<Quote>(),
//         quoteType: type_info::type_of<Quote>(),
//         maxBid: fixed_point_64::from_u128(2, 4),
//         bidSize: fixed_point_64::from_u128(4, 4),
//         minAsk: fixed_point_64::zero(),
//         askSize: fixed_point_64::zero(),
//         timestampMicroSeconds: 10,
//     };
//     assert_quote_eq(price, expectedPrice);
// }
//
// #[test(owner = @ferum, aptos = @0x1)]
// fun test_quote_empty_buy_book(owner: &signer, aptos: &signer) acquires OrderBook, UserMarketInfo {
//     // Tests quote is set correctly given an empty sell orderbook.
//
//     account::create_account_for_test(address_of(owner));
//     create_fake_coins(owner, 8);
//     register_fma(owner, owner, 50000000000);
//     register_fmb(owner, owner, 50000000000);
//     setup_market_for_test<FMA, FMB>(owner, aptos);
//
//     // Book setup.
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 3, 1, empty_client_order_id()); // SELL 0.0001 FMA @ 0.0003 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 3, 1, empty_client_order_id()); // SELL 0.0001 FMA @ 0.0003 FMB
//     add_order_entry<FMA, FMB>(owner, SIDE_SELL, TYPE_RESTING, 4, 1, empty_client_order_id()); // SELL 0.0001 FMA @ 0.0004 FMB
//
//     // Validate quote.
//     let book = borrow_global<OrderBook<FMA, FMB>>(get_market_addr<FMA, FMB>());
//     let price = get_quote(book);
//     let expectedPrice = Quote {
//         instrumentType: type_info::type_of<Quote>(),
//         quoteType: type_info::type_of<Quote>(),
//
//         maxBid: fixed_point_64::zero(),
//         bidSize: fixed_point_64::zero(),
//         minAsk: fixed_point_64::from_u128(3, 4),
//         askSize: fixed_point_64::from_u128(2, 4),
//         timestampMicroSeconds: 10,
//     };
//     assert_quote_eq(price, expectedPrice);
// }
//
// #[test_only]
// // Ignores timestamp.
// fun assert_quote_eq(quote: Quote, expected: Quote) {
//     assert!(fixed_point_64::eq(quote.maxBid, expected.maxBid), 0);
//     assert!(fixed_point_64::eq(quote.bidSize, expected.bidSize), 0);
//     assert!(fixed_point_64::eq(quote.minAsk, expected.minAsk), 0);
//     assert!(fixed_point_64::eq(quote.askSize, expected.askSize), 0);
// }
//
// #[test_only]
// public fun setup_market_for_test<I, Q>(owner: &signer, aptos: &signer) {
//     timestamp::set_time_has_started_for_testing(aptos);
//     init_ferum(owner, 0, 0, 0, 0);
//     init_market_entry<I, Q>(owner, 4, 4);
// }
//
// #[test_only]
// public fun setup_market_for_test_with_decimals<I, Q>(owner: &signer, aptos: &signer, iDecimal: u8, qDecimal: u8) {
//     timestamp::set_time_has_started_for_testing(aptos);
//     init_ferum(owner, 0, 0, 0, 0);
//     init_market_entry<I, Q>(owner, iDecimal, qDecimal);
// }
//
// #[test_only]
// public fun get_order<I, Q>(book: &OrderBook<I, Q>, orderID: OrderID): &Order<I, Q> {
//     let orderMap = &book.orderMap;
//     let contains = table::contains(orderMap, orderID);
//     if (contains) {
//         table::borrow(orderMap, orderID)
//     } else {
//         table::borrow(&book.finalizedOrderMap, orderID)
//     }
// }
//
// #[test_only]
// public fun get_order_metadatas_for_owner_external<I, Q>(signer: &signer): vector<OrderMetadata> acquires OrderBook {
//     let book = borrow_global<OrderBook<I, Q>>(get_market_addr<I, Q>());
//
//     if (!table::contains(&book.signerToOrders, address_of(signer))) {
//         return vector::empty()
//     };
//
//     let orderIDs = table::borrow(&book.signerToOrders, address_of(signer));
//     let orderIDsLength = vector::length(orderIDs);
//     let i = 0;
//     let out: vector<OrderMetadata> = vector::empty();
//     while (i < orderIDsLength) {
//         let id = *vector::borrow(orderIDs, i);
//         vector::push_back(&mut out, get_order(book, id).metadata);
//         i = i + 1;
//     };
//     out
// }
//
// #[test_only]
// fun empty_client_order_id(): String {
//     string::utf8(b"")
// }
//
// #[test_only]
// fun assert_order_finalized<I, Q>(book: &OrderBook<I, Q>, orderID: OrderID, status: u8) {
//     let order = get_order(book, orderID);
//     let orderStatus = order.metadata.status;
//     assert!(orderStatus == status, 0);
//     if (orderStatus == STATUS_CANCELLED) {
//         assert!(fixed_point_64::gt(order.metadata.remainingQty, fixed_point_64::zero()), 0);
//     } else {
//         assert!(fixed_point_64::eq(order.metadata.remainingQty, fixed_point_64::zero()), 0);
//     };
//     assert!(table::contains(&book.finalizedOrderMap, orderID), 0);
//     assert!(coin::value(&order.buyCollateral) == 0, 0);
//     assert!(coin::value(&order.sellCollateral) == 0, 0);
// }
//
// //
// // Test only accessors for external packages.
// //
//
// #[test_only]
// public fun get_order_price(metadata: &OrderMetadata): FixedPoint64 {
//     metadata.price
// }
//
// #[test_only]
// public fun get_order_side(metadata: &OrderMetadata): u8 {
//     metadata.side
// }
//
// #[test_only]
// public fun get_order_original_qty(metadata: &OrderMetadata): FixedPoint64 {
//     metadata.originalQty
// }