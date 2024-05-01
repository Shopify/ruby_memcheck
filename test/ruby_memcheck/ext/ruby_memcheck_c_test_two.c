#include <ruby.h>

static VALUE cRubyMemcheckCTestTwo;

static VALUE c_test_two_no_memory_leak(VALUE _)
{
    return Qnil;
}

/* This function must not be inlined to ensure that it has a stack frame. */
static void __attribute__((noinline)) c_test_two_allocate_memory_leak(void)
{
    volatile char *ptr = malloc(100);
    ptr[0] = 'a';
}

static VALUE c_test_two_memory_leak(VALUE _)
{
    c_test_two_allocate_memory_leak();
    return Qnil;
}

static VALUE c_test_two_use_after_free(VALUE _)
{
    volatile char *ptr = malloc(100);
    free((void *)ptr);
    ptr[0] = 'a';
    return Qnil;
}

static VALUE c_test_two_uninitialized_value(VALUE _)
{
    volatile int foo;
#pragma GCC diagnostic ignored "-Wuninitialized"
    return foo == 0 ? rb_str_new_cstr("zero") : rb_str_new_cstr("not zero");
#pragma GCC diagnostic pop
}

static VALUE c_test_two_call_into_ruby_mem_leak(VALUE obj)
{
    VALUE string = rb_eval_string("String.new(capacity: 10_000)");
    RSTRING(string)->as.heap.ptr = NULL;

    return Qnil;
}

void Init_ruby_memcheck_c_test_two(void)
{
    /* Memory leaks in the Init functions should be ignored. */
    c_test_two_allocate_memory_leak();

    VALUE mRubyMemcheck = rb_define_module("RubyMemcheck");
    cRubyMemcheckCTestTwo = rb_define_class_under(mRubyMemcheck, "CTestTwo", rb_cObject);
    rb_global_variable(&cRubyMemcheckCTestTwo);

    rb_define_method(cRubyMemcheckCTestTwo, "no_memory_leak", c_test_two_no_memory_leak, 0);
    rb_define_method(cRubyMemcheckCTestTwo, "memory_leak", c_test_two_memory_leak, 0);
    rb_define_method(cRubyMemcheckCTestTwo, "use_after_free", c_test_two_use_after_free, 0);
    rb_define_method(cRubyMemcheckCTestTwo, "uninitialized_value", c_test_two_uninitialized_value, 0);
    rb_define_method(cRubyMemcheckCTestTwo, "call_into_ruby_mem_leak", c_test_two_call_into_ruby_mem_leak, 0);
}
