#include <ruby.h>

VALUE cRubyMemcheckCTest;

static VALUE no_memory_leak(VALUE _)
{
    return Qnil;
}

static VALUE memory_leak(VALUE _)
{
    volatile char *ptr = malloc(100);
    ptr[0] = 'a';
    return Qnil;
}

static VALUE use_after_free(VALUE _)
{
    volatile char *ptr = malloc(100);
    free((void *)ptr);
    ptr[0] = 'a';
    return Qnil;
}

static VALUE uninitialized_value(VALUE _)
{
    volatile int foo;
#pragma GCC diagnostic ignored "-Wuninitialized"
    return foo == 0 ? rb_str_new_cstr("zero") : rb_str_new_cstr("not zero");
#pragma GCC diagnostic pop
}

void Init_ruby_memcheck_c_test(void)
{
    VALUE mRubyMemcheck = rb_define_module("RubyMemcheck");
    cRubyMemcheckCTest = rb_define_class_under(mRubyMemcheck, "CTest", rb_cObject);
    rb_global_variable(&cRubyMemcheckCTest);

    rb_define_method(cRubyMemcheckCTest, "no_memory_leak", no_memory_leak,  0);
    rb_define_method(cRubyMemcheckCTest, "memory_leak", memory_leak, 0);
    rb_define_method(cRubyMemcheckCTest, "use_after_free", use_after_free, 0);
    rb_define_method(cRubyMemcheckCTest, "uninitialized_value", uninitialized_value, 0);
}
